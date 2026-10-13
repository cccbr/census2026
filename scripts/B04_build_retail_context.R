# B04_build_retail_context.R ---------------------------------------------------
#
# How far each tower is from a shopping centre, and of what kind (D-037).
#
# Source: CDRC / GeoDS Retail Centre Boundaries (UK), downloaded by hand after
# registration from https://data.geods.ac.uk/dataset/retail-centre-boundaries
# into data/raw/cdrc_retail/<date>/ and checksummed in the fetch log. Open
# Government Licence. 9,623 retail centres, each classified by size and
# setting.
#
# Retail parks and shopping centres are left out: they are out-of-town
# destinations, not the centre of a place. The rest form a hierarchy of high
# streets, given a tier here (1 = largest):
#
#   1 Regional Centre   2 Major Town Centre   3 Town Centre, Market Town
#   4 District Centre   5 Local Centre        6 Small Local Centre
#
# Output, one row per tower in context scope:
#   retail_d_t<k>_m   metres from the church to the nearest retail centre of
#                     tier k or above (k = 3, 4, 5, 6); 0 inside one
#   retail_nearest_class, retail_nearest_name, retail_nearest_m
#                     the nearest retail centre of any tier
#   retail_covered    TRUE where the CDRC data covers the tower (the UK);
#                     FALSE abroad, where the distances are NA
#
# data/curated/tower_retail_<frame snapshot>.parquet (+ .json sidecar)

source(here::here("scripts", "00_setup.R"))
library(sf)

FRAME_SNAPSHOT  <- "dove_2026-09-19"
CDRC_SNAPSHOT   <- "cdrc_retail_2026-10-11"
CDRC_FILE       <- "retailcentre_bounds_uk.parquet"

RETAIL_TIERS <- c("Regional Centre" = 1, "Major Town Centre" = 2,
                  "Town Centre" = 3, "Market Town" = 3,
                  "District Centre" = 4, "Local Centre" = 5,
                  "Small Local Centre" = 6)

# ---- the file as received, checked against the fetch log ---------------------
log <- read_fetch_log() |>
  dplyr::filter(.data$snapshot_id == CDRC_SNAPSHOT, .data$file == CDRC_FILE)
stopifnot("CDRC file not in the fetch log" = nrow(log) == 1)
raw_path <- fs::path(snapshot_dir("cdrc_retail", sub(".*_", "", CDRC_SNAPSHOT)), CDRC_FILE)
verify_sha256(raw_path, log$sha256[[1]])

# GeoParquet: geometry is well-known binary in WGS84. Read with arrow and
# convert, which does not depend on GDAL's Parquet driver.
rc <- arrow::read_parquet(raw_path)
rc <- sf::st_sf(
  rc |> dplyr::select(-"geometry"),
  geometry = sf::st_as_sfc(structure(as.list(rc$geometry), class = "WKB"), crs = 4326)
)
unknown <- setdiff(unique(rc$Classification), c(names(RETAIL_TIERS),
                                                "Small Retail Park", "Large Retail Park",
                                                "Small Shopping Centre", "Large Shopping Centre"))
if (length(unknown) > 0) {
  stop("Unexpected retail centre classes: ", paste(unknown, collapse = ", "),
       ". Decide their tier before going on.", call. = FALSE)
}
rc <- rc |>
  dplyr::filter(.data$Classification %in% names(RETAIL_TIERS)) |>
  dplyr::mutate(tier = unname(RETAIL_TIERS[.data$Classification])) |>
  sf::st_transform(27700)                  # British National Grid, metres
message(nrow(rc), " retail centres on high streets (retail parks and shopping centres left out)")

# ---- towers ----------------------------------------------------------------
frame <- arrow::read_parquet(here::here("data", "curated", paste0("frame_", FRAME_SNAPSHOT, ".parquet")))
locations <- arrow::read_parquet(here::here("data", "curated",
                                            paste0("tower_locations_", FRAME_SNAPSHOT, ".parquet")))
towers <- locations |>
  dplyr::filter(.data$tower_id %in% context_scope(frame), !is.na(.data$lat), !is.na(.data$lon)) |>
  dplyr::left_join(frame |> dplyr::distinct(.data$tower_id, .keep_all = TRUE) |>
                     dplyr::select("tower_id", "country", "county"), by = "tower_id")
# The CDRC data covers the UK: Great Britain and Northern Ireland. Dove files
# the island of Ireland as one country, so its six northern counties are named.
NI_COUNTIES <- c("Antrim", "Armagh", "Down", "Fermanagh", "Derry", "Londonderry", "Tyrone")
towers$retail_covered <- towers$country %in% c("England", "Wales", "Scotland") |
  (towers$country == "Island of Ireland" & towers$county %in% NI_COUNTIES)

pts <- sf::st_as_sf(towers |> dplyr::filter(.data$retail_covered),
                    coords = c("lon", "lat"), crs = 4326) |>
  sf::st_transform(27700)

nearest_of <- function(centres) {
  i <- sf::st_nearest_feature(pts, centres)
  list(i = i, d = as.numeric(sf::st_distance(pts, centres[i, ], by_element = TRUE)))
}
dist_cols <- purrr::map(c(3, 4, 5, 6), \(k) nearest_of(dplyr::filter(rc, .data$tier <= k))$d)
names(dist_cols) <- paste0("retail_d_t", c(3, 4, 5, 6), "_m")
any_tier <- nearest_of(rc)

retail <- tibble::tibble(tower_id = pts$tower_id, !!!dist_cols,
                         retail_nearest_class = rc$Classification[any_tier$i],
                         retail_nearest_name  = rc$RC_Name[any_tier$i],
                         retail_nearest_m     = any_tier$d) |>
  dplyr::mutate(dplyr::across(dplyr::ends_with("_m"), \(x) round(x)))
retail <- towers |>
  dplyr::select("tower_id", "retail_covered") |>
  dplyr::left_join(retail, by = "tower_id")

stopifnot(!any(duplicated(retail$tower_id)))
message(sum(retail$retail_covered), " towers covered; ",
        sum(retail$retail_d_t4_m <= 250, na.rm = TRUE),
        " within 250 m of a district centre or larger")

out <- here::here("data", "curated", paste0("tower_retail_", FRAME_SNAPSHOT, ".parquet"))
write_artefact(retail, path = out, snapshot_id = c(FRAME_SNAPSHOT, CDRC_SNAPSHOT),
               script = "scripts/B04_build_retail_context.R")
message("Wrote ", out)
