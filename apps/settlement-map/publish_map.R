# apps/settlement-map/publish_map.R -----------------------------------------
#
# Publish an interactive map of the draft settlement types, for the analysis
# volunteers to pan around and check (Mark, 2026-10-11).
#
# Writes docs/settlement-map/index.html, served by GitHub Pages alongside the
# questionnaire tower list (D-021). The page is one self-contained file: the
# tower data is embedded as JSON (data, never code), so it also opens straight
# from disk. Leaflet and the OpenStreetMap tiles load from the web.
#
# The types come from the saved classification,
# data/curated/tower_classes_<snapshot>.parquet, written by
# scripts/B05_build_tower_classes.R. So the map shows exactly what the sample
# draw will use. Re-run B05, then this script, after changing the thresholds
# in config/choices.R or re-running B03 or B04.
#
# Contents: frame towers, plus unringable rings shown faded (Mark,
# 2026-10-11), so volunteers can see every tower with bells when judging
# city cores. Unringable rings are outside the frame (D-002) and play no part
# in any other tower's type; each is given the type its own place would
# have, by the same rule. Place measures, bells, type, and a known tower's
# "feels like" where one is recorded. No personal data: known_by is not
# exported.

source(here::here("scripts", "00_setup.R"))

cur <- \(stem) here::here("data", "curated", paste0(stem, "_", FRAME_SNAPSHOT, ".parquet"))
classes   <- arrow::read_parquet(cur("tower_classes"))
locations <- arrow::read_parquet(cur("tower_locations"))
context   <- arrow::read_parquet(cur("tower_context"))
retail    <- arrow::read_parquet(cur("tower_retail"))
known     <- readr::read_csv(here::here("data", "reference", "known_towers.csv"),
                             col_types = readr::cols(.default = "c"))

TEMPLATE <- here::here("apps", "settlement-map", "map_template.html")
OUT_DIR  <- here::here("docs", "settlement-map")
MAX_BYTES <- 1048576   # the pre-commit hook blocks files over 1 MiB

# The chapters' palette: one colour per type, in TYPE_LEVELS order.
type_colours <- TYPE_COLOURS   # config/choices.R

# Frame towers, plus unringable rings shown faded (ringable = FALSE).
shown <- classes |>
  dplyr::filter(.data$in_frame | !.data$ringable) |>
  dplyr::mutate(type = factor(.data$type, levels = TYPE_LEVELS),
                ur   = as.integer(!.data$ringable)) |>
  dplyr::inner_join(locations, by = "tower_id") |>
  dplyr::left_join(context |> dplyr::select("tower_id", "pop_r1km", "urban_pop",
                                            "pop_k2km", "pop_k250m", "land_km2_k2km",
                                            "land_km2_k250m", dplyr::all_of(c(NRES_VAR, REGION_VAR))),
                   by = "tower_id") |>
  dplyr::left_join(retail |> dplyr::select("tower_id", "retail_nearest_name",
                                           "retail_nearest_class", "retail_nearest_m",
                                           "retail_d_t4_m"),
                   by = "tower_id") |>
  dplyr::mutate(beyond_walk = beyond_walk(.data$pop_k2km, .data$pop_k250m,
                                          .data$land_km2_k2km, .data$land_km2_k250m))
message(sum(shown$ur == 1L), " unringable rings mapped.")

# Urban centres go in a lookup table, so each tower carries a small index
# rather than repeating its centre's figures (the page must stay under 1 MiB).
centres <- shown |>
  dplyr::filter(!is.na(.data$centre_key)) |>
  dplyr::distinct(.data$centre_key, .data$centre_pop) |>
  dplyr::mutate(centre = dplyr::row_number() - 1L)

# Retail centres too: name and class once each; towers carry an index.
shops <- shown |>
  dplyr::filter(!is.na(.data$retail_nearest_name)) |>
  dplyr::distinct(.data$retail_nearest_name, .data$retail_nearest_class) |>
  dplyr::mutate(shop = dplyr::row_number() - 1L)

rows <- shown |>
  dplyr::left_join(known |> dplyr::select("tower_id", "feels_like"), by = "tower_id") |>
  dplyr::left_join(shops, by = c("retail_nearest_name", "retail_nearest_class")) |>
  dplyr::left_join(centres |> dplyr::select("centre_key", "centre"), by = "centre_key") |>
  dplyr::transmute(
    lat   = round(.data$lat, 4),                    # about 10 m
    lon   = round(.data$lon, 4),
    label = .data$display,
    bells = .data$bells,
    type  = as.integer(.data$type) - 1L,            # 0-based for JavaScript
    density = signif(.data$local_density, 3),        # 250 m kernel
    beyond = signif(.data$beyond_walk, 2),           # density beyond a short walk
    shop  = .data$shop,                              # nearest retail centre (index)
    shop_m = .data$retail_nearest_m,                 # ... metres to it
    dc_m  = .data$retail_d_t4_m,                     # metres to a District Centre or larger
    nres  = round(.data[[NRES_VAR]], 3),             # non-residential share
    nres_ratio = round(.data$nres_ratio, 2),         # ... against its built-up area's
    pop1k = signif(.data$pop_r1km, 2),               # people within 1 km
    settle = signif(.data$urban_pop, 3),             # urban cluster population, if any
    centre = .data$centre,
    towers_1km = round(.data$towers_1km),
    cl    = as.integer(.data$tower_cluster),         # 1 = in a tower cluster
    region = signif(.data[[REGION_VAR]], 3),
    feels = .data$feels_like,
    ur    = .data$ur                                # 1 = unringable, shown faded
  )
stopifnot("every tower needs a type" = !anyNA(rows$type),
          "coordinates must be complete" = !anyNA(rows$lat) && !anyNA(rows$lon))

payload <- list(
  snapshot  = FRAME_SNAPSHOT,
  generated = format(Sys.Date(), "%d %B %Y"),
  types     = TYPE_LEVELS,
  types1988 = unname(crosswalk_1988[TYPE_LEVELS]),
  colours   = type_colours,
  centres   = unname(purrr::map(signif(centres$centre_pop, 3), \(p) list(p))),
  # Short name (before the first ";") and class of each nearest retail centre.
  shops     = unname(purrr::map2(sub(";.*$", "", shops$retail_nearest_name),
                                 shops$retail_nearest_class, \(n, c) list(n, c))),
  fields    = names(rows),
  rows      = purrr::pmap(rows, \(...) unname(list(...)))   # arrays, not objects
)
json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null",
                         digits = NA)
# Inside a <script> element, "</" would end it early. Escape it.
json <- gsub("</", "<\\/", json, fixed = TRUE)

html <- readr::read_file(TEMPLATE)
stopifnot("template has no /*DATA*/ placeholder" = grepl("/*DATA*/", html, fixed = TRUE))
html <- sub("/*DATA*/", json, html, fixed = TRUE)

fs::dir_create(OUT_DIR)
out <- fs::path(OUT_DIR, "index.html")
readr::write_file(html, out)

size <- fs::file_size(out)
message("Wrote ", out, " (", format(size), ", ", nrow(rows), " towers)")
if (as.numeric(size) > MAX_BYTES) {
  stop("The map page is over 1 MiB, which the pre-commit hook will block. ",
       "Trim fields or round further.", call. = FALSE)
}
