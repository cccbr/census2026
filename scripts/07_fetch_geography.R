# 07_fetch_geography.R --------------------------------------------------------
#
# Fetch immutable, checksummed snapshots of the external geography used to
# enrich tower locations:
#
#   ghsl_pop    GHS-POP R2023A, residential population per 100 m cell, World
#               Mollweide. Only the 1000 km tiles that contain an enrichment
#               window are downloaded. Britain needs about four.
#   ghsl_smod   GHS-SMOD R2023A, Degree of Urbanisation level 2, 1 km, global.
#               About 34 MB.
#   ons_oa_ruc  ONS Output Areas (Dec 2021) BGC V2 with the 2021 Rural Urban
#               Classification attached. England and Wales only.
#
# Each source lands in data/raw/<source>/<date>/ and gets one fetch_log row
# per file, as Dove does. Zips are stored as fetched. Unzipping happens in
# script 08, into data/interim/, so the raw bytes stay exactly as recorded.
#
# Run interactively. It refuses to overwrite an existing snapshot.
#
# LICENCES
#   GHSL: (c) European Union. "Reuse is authorised, provided the source is
#   acknowledged." Cite Schiavina et al. (2023) GHS-POP R2023A and
#   GHS-SMOD R2023A.
#   ONS boundaries: Open Government Licence v3; contains OS data (c) Crown
#   copyright and database right.

source(here::here("scripts", "00_setup.R"))

library(httr2)

FRAME_SNAPSHOT <- "dove_2026-09-19"   # tiles are chosen from these towers

# Q-021 OPEN: population epoch. GHSL's 2025 and 2030 epochs are projections,
# described by JRC as "projections to 2025 and 2030 derived from CIESIN
# GPWv4.11". 2020 is the latest epoch not labelled a projection. SMOD uses the
# same epoch so that the two layers agree.
GHSL_EPOCH <- "E2020"

# The widest kernel decides how far beyond a tower population is needed: about
# 77 km for an 8 km half-distance. Keep this in step with MEASURES in script 08
# (D-026).
MAX_HALF_DISTANCE_M <- 8000

fetch_date <- Sys.Date()
UA <- "CCCBR Ringing Census 2026 (https://github.com/cccbr/ringing-census-2026)"

# ---- URLs -------------------------------------------------------------------

GHSL_ROOT <- "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL"

ghsl_pop_tile_url <- function(tile, epoch = GHSL_EPOCH) {
  stem <- paste0("GHS_POP_", epoch, "_GLOBE_R2023A_54009_100")
  paste0(GHSL_ROOT, "/GHS_POP_GLOBE_R2023A/", stem, "/V1-0/tiles/",
         stem, "_V1_0_", tile, ".zip")
}

GHSL_SMOD_URL <- local({
  stem <- paste0("GHS_SMOD_", GHSL_EPOCH, "_GLOBE_R2023A_54009_1000")
  paste0(GHSL_ROOT, "/GHS_SMOD_GLOBE_R2023A/", stem, "/V2-0/", stem, "_V2_0.zip")
})

# ArcGIS Hub download API for "Output Areas (December 2021) Boundaries EW BGC
# (V2) and Rural Urban Classification". The item id comes from the
# data.gov.uk resource page for that dataset.
ONS_OA_RUC_URL <- paste0(
  "https://open-geography-portalx-ons.hub.arcgis.com/api/download/v1/items/",
  "ba871c7913184894b9c8dece9a542dfc/shapefile?layers=0"
)

# ---- which GHSL tiles? ------------------------------------------------------
#
# GHSL Mollweide tiles are 1000 km squares named R<row>_C<col>. The origin is
# x = -18,041,000 m, y = 9,000,000 m. That grid is documented by a third-party
# mirror, not by JRC. So script 08 checks every downloaded tile's actual extent
# against it, and stops if they disagree.

GHSL_X0   <- -18041000
GHSL_Y0   <-   9000000
GHSL_SPAN <-   1000000

ghsl_tile_id <- function(x, y) {
  paste0("R", floor((GHSL_Y0 - y) / GHSL_SPAN) + 1,
         "_C", floor((x - GHSL_X0) / GHSL_SPAN) + 1)
}

locations <- arrow::read_parquet(here::here(
  "data", "curated", paste0("tower_locations_", FRAME_SNAPSHOT, ".parquet")
))
frame <- arrow::read_parquet(here::here(
  "data", "curated", paste0("frame_", FRAME_SNAPSHOT, ".parquet")
))

in_scope <- locations |>
  dplyr::filter(.data$tower_id %in% context_scope(frame),
                !is.na(.data$lat), !is.na(.data$lon))

cutoff_m <- kernel_cutoff_m(MAX_HALF_DISTANCE_M)

# For each tower, sample the edge of its widest window and record every tile
# the window touches. Tiles are 1000 km across and windows about 100 km, so
# edge samples cannot miss a tile.
tiles <- purrr::map2(in_scope$lon, in_scope$lat, \(x, y) {
  ring <- rbind(c(x, y), destination_points(x, y, cutoff_m * 1.02))
  xy   <- sf::sf_project(from = "OGC:CRS84", to = "ESRI:54009", pts = ring)
  unique(ghsl_tile_id(xy[, 1], xy[, 2]))
}) |>
  unlist() |>
  unique() |>
  sort()

message(length(tiles), " GHSL population tiles needed: ",
        paste(tiles, collapse = ", "))

# ---- fetch helper -----------------------------------------------------------

new_snapshot_dir <- function(source) {
  dest <- snapshot_dir(source, fetch_date)
  if (fs::dir_exists(dest) && length(fs::dir_ls(dest)) > 0) {
    stop("A snapshot already exists at:\n  ", dest,
         "\nRaw snapshots are immutable.", call. = FALSE)
  }
  fs::dir_create(dest)
}

#' Download one URL to `out`. Returns one fetch_log row.
#'
#' A 404 is recorded rather than raised when `allow_404` is TRUE. GHSL omits
#' tiles that are entirely ocean, and the log should show that a tile was
#' asked for and found absent, not leave it unexplained.
fetch_file <- function(url, out, snapshot_id, source, allow_404 = FALSE) {
  message("Fetching ", fs::path_file(out))

  # The ArcGIS Hub API can answer 202 with a JSON status while it builds the
  # export, then serve the file on a later request. Poll politely.
  for (attempt in 1:20) {
    resp <- request(url) |>
      req_user_agent(UA) |>
      req_timeout(1800) |>
      req_retry(max_tries = 3) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform(path = out)
    ctype <- resp_content_type(resp) %||% ""
    building <- resp_status(resp) == 202 || grepl("json", ctype)
    if (!building) break
    message("  export not ready (", resp_status(resp), "); waiting 15 s")
    Sys.sleep(15)
  }

  status <- resp_status(resp)
  if (status == 404 && allow_404) {
    fs::file_delete(out)
  } else if (status != 200 || building) {
    stop("Fetch failed: HTTP ", status, " (", ctype, ") for ", url, call. = FALSE)
  }
  present <- status == 200

  tibble::tibble(
    snapshot_id    = snapshot_id,
    source         = source,
    file           = fs::path_file(out),
    url            = url,
    fetched_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    http_status    = status,
    etag           = resp_header(resp, "etag")          %||% NA_character_,
    last_modified  = resp_header(resp, "last-modified") %||% NA_character_,
    bytes          = if (present) as.numeric(fs::file_size(out)) else NA_real_,
    n_rows         = NA_integer_,     # binary archives: no row count
    sha256         = if (present) file_sha256(out) else NA_character_,
    fetched_by     = Sys.info()[["user"]]
  )
}

record <- function(manifest, dest, extra = list()) {
  jsonlite::write_json(
    c(list(files = manifest), extra),
    fs::path(dest, "_manifest.json"),
    auto_unbox = TRUE, pretty = TRUE
  )
  purrr::pwalk(manifest, \(...) append_fetch_log(tibble::tibble(...)))
  print(manifest |> dplyr::select(file, http_status, bytes))
}

# ---- GHSL population tiles --------------------------------------------------

src  <- "ghsl_pop"
sid  <- paste0(src, "_", GHSL_EPOCH, "_", format(fetch_date, "%Y-%m-%d"))
dest <- new_snapshot_dir(src)

pop_manifest <- purrr::map(tiles, \(t) {
  url <- ghsl_pop_tile_url(t)
  fetch_file(url, fs::path(dest, fs::path_file(url)), sid, src, allow_404 = TRUE)
}) |>
  purrr::list_rbind()

record(pop_manifest, dest, extra = list(
  epoch = GHSL_EPOCH,
  tiles_requested = tiles,
  tiles_chosen_from = FRAME_SNAPSHOT,
  max_half_distance_m = MAX_HALF_DISTANCE_M
))

# ---- GHSL SMOD --------------------------------------------------------------

src  <- "ghsl_smod"
sid  <- paste0(src, "_", GHSL_EPOCH, "_", format(fetch_date, "%Y-%m-%d"))
dest <- new_snapshot_dir(src)

smod_manifest <- fetch_file(
  GHSL_SMOD_URL, fs::path(dest, fs::path_file(GHSL_SMOD_URL)), sid, src
)
record(smod_manifest, dest, extra = list(epoch = GHSL_EPOCH))

# ---- ONS OA 2021 boundaries + RUC 2021 --------------------------------------

src  <- "ons_oa_ruc"
sid  <- paste0(src, "_", format(fetch_date, "%Y-%m-%d"))
dest <- new_snapshot_dir(src)

ons_manifest <- fetch_file(
  ONS_OA_RUC_URL, fs::path(dest, "OA_2021_EW_BGC_V2_RUC.zip"), sid, src
)
record(ons_manifest, dest)

message(
  "\nDone. Snapshot ids:\n  ",
  paste(unique(c(pop_manifest$snapshot_id, smod_manifest$snapshot_id,
                 ons_manifest$snapshot_id)), collapse = "\n  "),
  "\n\nNEXT: commit provenance/fetch_log.csv, then set these ids at the top of",
  " scripts/08_build_tower_context.R"
)
