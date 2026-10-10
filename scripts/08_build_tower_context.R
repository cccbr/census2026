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

# ---- GHSL population: 100 m mosaic, plus a 1 km aggregate -------------------

pop_tifs <- fs::dir_ls(pop_dir, recurse = TRUE, regexp = "R\\d+_C\\d+\\.tif$")

# The tile grid used to choose downloads came from a third-party mirror's
# documentation. Check it against the tiles' own extents before relying on it.
# A disagreement means script 07 may have skipped a tile it needed.
purrr::walk(pop_tifs, \(f) {
  id <- regmatches(f, regexpr("R\\d+_C\\d+", f))
  rc <- as.integer(regmatches(id, gregexpr("\\d+", id))[[1]])
  e  <- as.vector(terra::ext(terra::rast(f)))
  expected <- c(xmin = -18041000 + (rc[2] - 1) * 1e6,
                xmax = -18041000 + rc[2] * 1e6,
                ymin = 9000000 - rc[1] * 1e6,
                ymax = 9000000 - (rc[1] - 1) * 1e6)
  if (any(abs(e - expected) > 1)) {
    stop("Tile ", id, " extent does not match the assumed GHSL grid.\n",
         "  actual:   ", paste(e, collapse = ", "), "\n",
         "  expected: ", paste(expected, collapse = ", "), call. = FALSE)
  }
})

pop_100m <- terra::vrt(pop_tifs, filename = fs::path(pop_dir, "pop_100m.vrt"),
                       overwrite = TRUE)

# Aggregate tile by tile, not the whole mosaic. A mosaic spanning Britain and
# Australia is mostly empty, and aggregating it whole would read the empty
# part too.
agg_dir <- fs::dir_create(here::here("data", "interim",
                                     paste0(GHSL_POP_SNAPSHOT, "_agg1km")))
agg_tifs <- purrr::map_chr(pop_tifs, \(f) {
  out <- fs::path(agg_dir, fs::path_file(f))
  if (!fs::file_exists(out)) {
    terra::aggregate(terra::rast(f), fact = 10, fun = "sum", na.rm = TRUE,
                     filename = out)
  }
  out
})
pop_1km <- terra::vrt(agg_tifs, filename = fs::path(agg_dir, "pop_1km.vrt"),
                      overwrite = TRUE)

pop_raster <- list(`100` = pop_100m, `1000` = pop_1km)

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
# Dry-run timing on synthetic rasters: about 0.1 s per tower for the 100 m
# group, so 10-15 minutes for about 7,000 towers, plus a few minutes for 1 km.

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
  bell_cols  |> dplyr::rename_with(\(x) paste0("bells_", x))
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
        NA_real_)
    )
}

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
                  ONS_RUC_SNAPSHOT),
  script      = "scripts/08_build_tower_context.R"
)

message("Wrote ", out)
