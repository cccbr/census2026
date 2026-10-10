# 08_build_tower_context.R ----------------------------------------------------
#
# Enrich tower locations with settlement context. One row per tower, keyed on
# tower_id. Join to the frame on tower_id; the frame key stays RingID (D-007).
#
#   smod_*         GHSL Degree of Urbanisation level 2 at the tower's 1 km cell.
#                  The same definition is used everywhere in the world.
#   oa21cd, ruc21* ONS 2021 Rural Urban Classification of the tower's Output
#                  Area. England and Wales only; NA elsewhere. Included for
#                  completeness and comparison, not as the preferred measure.
#   For each measure <m> in MEASURES (D-026), either an exponential kernel
#   ("k2km" = weight halves every 2 km) or a plain radius ("r5km"):
#   pop_<m>        Residential population, weighted by distance.
#   towers_<m>     Weighted count of FRAME towers, including this tower if it is
#                  one.
#   bells_<m>      Weighted count of FRAME bells, likewise.
#   pop_per_tower_<m>, pop_per_bell_<m>
#                  The ratios. Frame towers only. NA for towers outside the
#                  frame, because the denominator is defined by the frame.
#   area_km2_<m>   The measure's total weighted area: a constant per measure,
#                  stored so densities can be checked.
#   land_km2_<m>   Weighted LAND area (GHSL land layer).
#   land_share_<m> Share of the measure's weight that falls on land. Low near
#                  coasts and estuaries.
#   density_<m>    People per km2 of all surface, land and sea.
#   density_land_<m>
#                  People per km2 of land. Comparable across scales, so the
#                  ratio of a narrow to a wide density measures isolation
#                  without the sea counting as emptiness.
#
# Output: data/curated/tower_context_<frame snapshot>.parquet (+ .json sidecar)

source(here::here("scripts", "00_setup.R"))

library(sf)
library(terra)

# ---- snapshots: named, never discovered -------------------------------------

FRAME_SNAPSHOT     <- "dove_2026-09-19"
GHSL_POP_SNAPSHOT  <- "ghsl_pop_E2020_2026-10-10"
GHSL_SMOD_SNAPSHOT <- "ghsl_smod_E2020_2026-10-10"
ONS_RUC_SNAPSHOT   <- "ons_oa_ruc_2026-10-10"
GHSL_LAND_SNAPSHOT <- "ghsl_land_E2018_2026-10-10"

# ---- OPEN decisions encoded here: do not let these harden silently ----------

# D-026 (Provisional): distance measures.
#
# Kernels: half-distances doubling from 1 to 8 km. 2 km is the prior mode for
# the local catchment. Published travel data for weekly voluntary activities
# implies 1.5-2.3 km: Sport England FPM pools and halls, and US church
# attendance. 1 and 4 km bracket it for sensitivity, and 8 km stands for the
# wider "travel to practice" market.
#
# Radii: plain circular counts at round distances, for communication.
#
# pop_res_m is the population raster used: 100 m wherever the reach allows,
# 1 km for the wide kernels. A 4 km kernel reaches about 38 km, which at 100 m
# would be 770 x 770 cells per tower. Measures sharing a resolution share one
# window per tower, so the radii cost almost nothing beyond the 2 km kernel,
# which already reaches about 19 km.
MEASURES <- tibble::tribble(
  ~measure, ~type,    ~param_m, ~pop_res_m,
  "k1km",   "kernel",  1000,     100,
  "k2km",   "kernel",  2000,     100,
  "k4km",   "kernel",  4000,    1000,
  "k8km",   "kernel",  8000,    1000,
  "r1km",   "radius",  1000,     100,
  "r2km",   "radius",  2000,     100,
  "r5km",   "radius",  5000,     100,
  "r10km",  "radius", 10000,     100
)

# Considered and deferred (D-026): a Huff / three-step floating catchment
# allocation, splitting each population cell among the towers that reach it.
# The ratios below evaluate competition at the tower, not at the resident.

# Q-020 OPEN: bells at a tower with two frame rings. On dove_2026-09-19 this
# affects two towers only: Gresford (8 + 6) and Rugby (8 + 5). "max" counts the
# larger ring. "sum" counts every bell.
MULTI_RING_BELLS <- "max"

# Truncation tolerance for the kernel windows. This is numerical, not
# methodological: see kernel_cutoff_m().
KERNEL_TOL <- 0.01

# ---- verify raw bytes against the fetch log ---------------------------------

verify_snapshot <- function(snapshot_id) {
  rows <- read_fetch_log() |>
    dplyr::filter(.data$snapshot_id == !!snapshot_id, .data$http_status == 200)
  stopifnot("snapshot not in fetch log" = nrow(rows) > 0)
  src  <- rows$source[[1]]
  date <- sub(".*_(\\d{4}-\\d{2}-\\d{2})$", "\\1", snapshot_id)
  dir  <- snapshot_dir(src, date)
  purrr::pwalk(rows |> dplyr::select(file, sha256),
               \(file, sha256) verify_sha256(fs::path(dir, file), sha256))
  message("Checksums verified for ", snapshot_id)
  list(dir = dir, files = rows$file)
}

pop_raw  <- verify_snapshot(GHSL_POP_SNAPSHOT)
smod_raw <- verify_snapshot(GHSL_SMOD_SNAPSHOT)
ons_raw  <- verify_snapshot(ONS_RUC_SNAPSHOT)
land_raw <- verify_snapshot(GHSL_LAND_SNAPSHOT)

# Unzip into data/interim/. Raw stays exactly as fetched. Interim is
# disposable and rebuilt from raw.
unzip_to_interim <- function(raw, snapshot_id) {
  out <- here::here("data", "interim", snapshot_id)
  if (!fs::dir_exists(out)) {
    fs::dir_create(out)
    purrr::walk(raw$files, \(f) utils::unzip(fs::path(raw$dir, f), exdir = out))
  }
  out
}

pop_dir  <- unzip_to_interim(pop_raw,  GHSL_POP_SNAPSHOT)
smod_dir <- unzip_to_interim(smod_raw, GHSL_SMOD_SNAPSHOT)
ons_dir  <- unzip_to_interim(ons_raw,  ONS_RUC_SNAPSHOT)
land_dir <- unzip_to_interim(land_raw, GHSL_LAND_SNAPSHOT)

# ---- towers in scope --------------------------------------------------------

frame <- arrow::read_parquet(here::here(
  "data", "curated", paste0("frame_", FRAME_SNAPSHOT, ".parquet")
))
locations <- arrow::read_parquet(here::here(
  "data", "curated", paste0("tower_locations_", FRAME_SNAPSHOT, ".parquet")
))

towers <- locations |>
  dplyr::filter(.data$tower_id %in% context_scope(frame),
                !is.na(.data$lat), !is.na(.data$lon))

# Frame towers and their bells: the "competition" in the density measures. The
# frame is the agreed sampling frame, frame_full (D-017, D-019).
frame_towers <- frame |>
  dplyr::filter(.data$frame_full) |>
  dplyr::summarise(
    bells = if (MULTI_RING_BELLS == "max") max(.data$bells) else sum(.data$bells),  # Q-020
    n_frame_rings = dplyr::n(),
    .by = "tower_id"
  ) |>
  dplyr::inner_join(locations, by = "tower_id")

message(nrow(towers), " towers in scope; ", nrow(frame_towers), " frame towers")

# ---- GHSL tiled layers: 100 m mosaic, plus a 1 km aggregate ----------------
#
# Population and land share the same 1000 km tile grid, so one routine builds
# both.

#' The extent a GHSL tile ID should cover on the 1000 km grid
#'
#' The grid came from a third-party mirror's documentation, so each tile is
#' checked against it rather than trusted.
ghsl_tile_extent <- function(f) {
  id <- regmatches(f, regexpr("R\\d+_C\\d+", f))
  rc <- as.integer(regmatches(id, gregexpr("\\d+", id))[[1]])
  terra::ext(-18041000 + (rc[2] - 1) * 1e6, -18041000 + rc[2] * 1e6,
             9000000 - rc[1] * 1e6,        9000000 - (rc[1] - 1) * 1e6)
}

#' Check a set of GHSL tiles against the grid, and build a 100 m mosaic and a
#' 1 km aggregate
#'
#' A tile must sit INSIDE its grid square and on the 100 m lattice. It need not
#' fill it: GHS-LAND R2022A tiles are trimmed where the square is mostly sea
#' (R13_C29 starts 400 km in), while GHS-POP R2023A tiles fill the square. A
#' tile outside its square would mean script 07 chose tiles wrongly, and stops
#' the script.
#'
#' Before aggregating to 1 km, each tile is extended to its full square, so
#' every 1 km cell lines up with the same grid whatever the trimming.
#'
#' Aggregation is done tile by tile, not on the whole mosaic. A mosaic spanning
#' Britain and Australia is mostly empty, and aggregating it whole would read
#' the empty part too.
tiled_rasters <- function(dir, snapshot_id) {
  tifs <- fs::dir_ls(dir, recurse = TRUE, regexp = "R\\d+_C\\d+\\.tif$")
  stopifnot("no tiles found" = length(tifs) > 0)

  purrr::walk(tifs, \(f) {
    r   <- terra::rast(f)
    e   <- as.vector(terra::ext(r))
    exp <- as.vector(ghsl_tile_extent(f))
    inside  <- e[["xmin"]] >= exp[["xmin"]] - 1 && e[["xmax"]] <= exp[["xmax"]] + 1 &&
               e[["ymin"]] >= exp[["ymin"]] - 1 && e[["ymax"]] <= exp[["ymax"]] + 1
    on_grid <- all(abs(((e - exp) / 100) - round((e - exp) / 100)) < 1e-6) &&
               all(abs(terra::res(r) - 100) < 1e-6)
    if (!inside || !on_grid) {
      stop("Tile ", fs::path_file(f), " does not sit inside its GHSL grid square ",
           "on the 100 m lattice.\n",
           "  actual:   ", paste(e, collapse = ", "), "\n",
           "  expected within: ", paste(exp, collapse = ", "), call. = FALSE)
    }
  })

  r100 <- terra::vrt(tifs, filename = fs::path(dir, "mosaic_100m.vrt"),
                     overwrite = TRUE)

  agg_dir <- fs::dir_create(here::here("data", "interim",
                                       paste0(snapshot_id, "_agg1km")))
  agg_tifs <- purrr::map_chr(tifs, \(f) {
    out <- fs::path(agg_dir, fs::path_file(f))
    if (!fs::file_exists(out)) {
      terra::rast(f) |>
        terra::extend(ghsl_tile_extent(f)) |>
        terra::aggregate(fact = 10, fun = "sum", na.rm = TRUE, filename = out)
    }
    out
  })
  r1k <- terra::vrt(agg_tifs, filename = fs::path(agg_dir, "mosaic_1km.vrt"),
                    overwrite = TRUE)

  list(`100` = r100, `1000` = r1k, first_tile = tifs[[1]])
}

pop_raster  <- tiled_rasters(pop_dir,  GHSL_POP_SNAPSHOT)
land_raster <- tiled_rasters(land_dir, GHSL_LAND_SNAPSHOT)

# GHS-LAND's unit is checked, not assumed. Per 100 m cell it is either land
# area in m2 (0-10,000) or a land fraction (0-1). The maximum over a tile with
# open country tells them apart. Anything else stops the script.
land_max <- terra::global(terra::rast(land_raster$first_tile), "max", na.rm = TRUE)[[1]]
land_to_km2 <- dplyr::case_when(
  abs(land_max - 1e4) < 1   ~ 1e-6,   # m2 per cell  -> km2
  abs(land_max - 1)   < 1e-6 ~ 0.01,  # fraction     -> km2 (cell is 0.01 km2)
  TRUE ~ NA_real_
)
if (is.na(land_to_km2)) {
  stop("GHS-LAND maximum per 100 m cell is ", land_max,
       "; expected 10000 (m2) or 1 (fraction). Check the unit before going on.",
       call. = FALSE)
}
message("GHS-LAND unit: ", if (land_to_km2 == 1e-6) "m2 per cell" else "fraction per cell")

# ---- SMOD: Degree of Urbanisation at the tower's cell -----------------------
#
# The quick, fragile steps run before the slow population sums, so a problem
# with a boundary file shows up in seconds, not after 15 minutes.

smod <- terra::rast(fs::dir_ls(smod_dir, recurse = TRUE, glob = "*.tif"))
pts  <- terra::vect(towers, geom = c("lon", "lat"), crs = "OGC:CRS84")

site <- towers |>
  dplyr::select("tower_id") |>
  dplyr::mutate(
    smod_code = as.integer(terra::extract(smod, terra::project(pts, terra::crs(smod)))[[2]])
  ) |>
  dplyr::left_join(SMOD_L2_CLASSES, by = "smod_code")

unexpected <- setdiff(stats::na.omit(site$smod_code), SMOD_L2_CLASSES$smod_code)
if (length(unexpected) > 0) {
  warning("Unexpected SMOD codes: ", paste(unexpected, collapse = ", "))
}

# ---- ONS RUC 2021 (England & Wales) -----------------------------------------

oa <- sf::read_sf(fs::dir_ls(ons_dir, recurse = TRUE, glob = "*.shp"))

# Columns by name. These are the names on the ONS FeatureServer layer.
# Shapefile export truncates names to 10 characters, so check before
# assuming they survived. (On ons_oa_ruc_2026-10-10 they did.)
needed <- c("OA21CD", "RUC21CD", "RUC21NM")
stopifnot("ONS layer is missing expected columns" = all(needed %in% names(oa)))

ruc_hits <- sf::st_as_sf(towers, coords = c("lon", "lat"), crs = 4326) |>
  sf::st_transform(sf::st_crs(oa)) |>
  sf::st_join(oa |> dplyr::select(dplyr::all_of(needed)),
              join = sf::st_intersects) |>
  sf::st_drop_geometry()

# Generalised (BGC) boundaries can overlap slightly, so a tower on a shared
# edge can fall in two OAs. Found on the real data: script 08 first stopped
# here. Where the candidate OAs agree on the RUC class, the class is kept.
# Where they disagree, the class is set to NA and flagged. Picking one would
# be a tie-break nobody chose.
ruc <- ruc_hits |>
  dplyr::summarise(
    n_oa       = dplyr::n_distinct(.data$OA21CD, na.rm = TRUE),
    n_class    = dplyr::n_distinct(.data$RUC21CD, na.rm = TRUE),
    oa21cd     = if (dplyr::n_distinct(.data$OA21CD) == 1) dplyr::first(.data$OA21CD) else NA_character_,
    ruc21cd    = if (dplyr::n_distinct(.data$RUC21CD) == 1) dplyr::first(.data$RUC21CD) else NA_character_,
    ruc21nm    = if (dplyr::n_distinct(.data$RUC21NM) == 1) dplyr::first(.data$RUC21NM) else NA_character_,
    .by = "tower_id"
  ) |>
  dplyr::mutate(ruc_ambiguous = .data$n_class > 1) |>
  dplyr::select(-"n_class")

message(sum(ruc$n_oa > 1), " towers sit on a boundary between OAs; ",
        sum(ruc$ruc_ambiguous), " of them between OAs of different RUC class (set to NA)")

# BGC boundaries are clipped to the coastline. A tower on a cliff edge or a
# quayside can fall just outside every polygon. Report it; do not snap it to
# the nearest OA silently.
ew_unmatched <- frame |>
  dplyr::filter(.data$country %in% c("England", "Wales")) |>
  dplyr::distinct(.data$tower_id) |>
  dplyr::inner_join(ruc, by = "tower_id") |>
  dplyr::filter(.data$n_oa == 0)
if (nrow(ew_unmatched) > 0) {
  message(nrow(ew_unmatched), " England/Wales towers fell outside every OA polygon: ",
          paste(ew_unmatched$tower_id, collapse = ", "))
}

site <- site |> dplyr::left_join(ruc |> dplyr::select(-"n_oa"), by = "tower_id")

# ---- distance measures ------------------------------------------------------
#
# Timing on the real British Isles data: about 12 minutes for population. Land
# repeats the same windows, so allow 25-30 minutes in total.

frame_src <- frame_towers |>
  dplyr::select("tower_id", "lon", "lat", "bells")

pop_cols <- MEASURES |>
  dplyr::group_split(.data$pop_res_m) |>
  purrr::map(\(m) {
    message("Population, ", nrow(m), " measures at ", m$pop_res_m[[1]], " m")
    raster_window_sums(towers$lon, towers$lat,
                       pop_raster[[as.character(m$pop_res_m[[1]])]], m, KERNEL_TOL)
  }) |>
  purrr::list_cbind()

land_cols <- MEASURES |>
  dplyr::group_split(.data$pop_res_m) |>
  purrr::map(\(m) {
    message("Land, ", nrow(m), " measures at ", m$pop_res_m[[1]], " m")
    raster_window_sums(towers$lon, towers$lat,
                       land_raster[[as.character(m$pop_res_m[[1]])]], m, KERNEL_TOL)
  }) |>
  purrr::list_cbind() |>
  dplyr::mutate(dplyr::across(dplyr::everything(), \(x) x * land_to_km2))

# Total weighted area of each measure, in km2. A kernel holds 2*pi/lambda^2 in
# total, less the share beyond its cutoff (KERNEL_TOL by construction). A
# radius holds pi*r^2.
measure_area_km2 <- purrr::pmap_dbl(MEASURES, \(type, param_m, ...) {
  if (type == "kernel") {
    lambda <- log(2) / param_m
    2 * pi / lambda^2 * (1 - KERNEL_TOL) / 1e6
  } else {
    pi * param_m^2 / 1e6
  }
})
names(measure_area_km2) <- MEASURES$measure

tower_cols <- point_window_sums(
  towers, frame_src |> dplyr::mutate(weight = 1), MEASURES, KERNEL_TOL
)
bell_cols <- point_window_sums(
  towers, frame_src |> dplyr::mutate(weight = .data$bells), MEASURES, KERNEL_TOL
)

context <- dplyr::bind_cols(
  towers |> dplyr::select("tower_id"),
  pop_cols   |> dplyr::rename_with(\(x) paste0("pop_", x)),
  tower_cols |> dplyr::rename_with(\(x) paste0("towers_", x)),
  bell_cols  |> dplyr::rename_with(\(x) paste0("bells_", x)),
  land_cols  |> dplyr::rename_with(\(x) paste0("land_km2_", x))
) |>
  dplyr::mutate(in_frame = .data$tower_id %in% frame_towers$tower_id)

# Ratios for frame towers only. towers_<m> and bells_<m> include the tower
# itself at weight 1, so the denominators are at least 1 and 4 respectively.
for (m in MEASURES$measure) {
  context <- context |>
    dplyr::mutate(
      !!paste0("pop_per_tower_", m) := dplyr::if_else(
        .data$in_frame, .data[[paste0("pop_", m)]] / .data[[paste0("towers_", m)]],
        NA_real_),
      !!paste0("pop_per_bell_", m) := dplyr::if_else(
        .data$in_frame, .data[[paste0("pop_", m)]] / .data[[paste0("bells_", m)]],
        NA_real_),
      !!paste0("area_km2_", m)   := measure_area_km2[[m]],
      !!paste0("land_share_", m) := .data[[paste0("land_km2_", m)]] / measure_area_km2[[m]],
      !!paste0("density_", m)    := .data[[paste0("pop_", m)]] / measure_area_km2[[m]],
      !!paste0("density_land_", m) := dplyr::if_else(
        .data[[paste0("land_km2_", m)]] > 0,
        .data[[paste0("pop_", m)]] / .data[[paste0("land_km2_", m)]],
        NA_real_)
    )
}

# Cell-centre sampling can push the land share fractionally over 1 inland.
# Anything well over 1 means the unit check above was wrong.
max_share <- max(dplyr::select(context, dplyr::starts_with("land_share_")), na.rm = TRUE)
message("Largest land share: ", round(max_share, 3))
if (max_share > 1.05) stop("Land share above 1.05: check the GHS-LAND unit.", call. = FALSE)

context <- context |> dplyr::left_join(site, by = "tower_id")

# ---- checks -----------------------------------------------------------------

stopifnot(!any(duplicated(context$tower_id)))

# A frame tower counts itself at weight 1, so its tower density is at least 1.
for (m in MEASURES$measure) {
  stopifnot(all(context[[paste0("towers_", m)]][context$in_frame] >= 1 - 1e-9))
}

# Frame towers where the narrowest population kernel came back zero. These
# should be rare. Lundy is the expected one. Many would mean missing tiles.
k1 <- MEASURES$measure[MEASURES$type == "kernel"][
  which.min(MEASURES$param_m[MEASURES$type == "kernel"])]
zero_pop <- context |>
  dplyr::filter(.data$in_frame, .data[[paste0("pop_", k1)]] == 0)
message(nrow(zero_pop), " frame towers with zero population in kernel ", k1)

context |>
  dplyr::filter(.data$in_frame) |>
  dplyr::count(.data$smod_class, sort = TRUE) |>
  print()

# ---- write ------------------------------------------------------------------

out <- here::here("data", "curated",
                  paste0("tower_context_", FRAME_SNAPSHOT, ".parquet"))

write_artefact(
  context,
  path        = out,
  snapshot_id = c(FRAME_SNAPSHOT, GHSL_POP_SNAPSHOT, GHSL_SMOD_SNAPSHOT,
                  ONS_RUC_SNAPSHOT, GHSL_LAND_SNAPSHOT),
  script      = "scripts/08_build_tower_context.R"
)

message("Wrote ", out)
