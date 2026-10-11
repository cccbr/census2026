# 10_export_settlement_map.R --------------------------------------------------
#
# Publish an interactive map of the draft settlement types, for the analysis
# volunteers to pan around and check (Mark, 2026-10-11).
#
# Writes docs/settlement-map/index.html, served by GitHub Pages alongside the
# questionnaire tower list (D-021). The page is one self-contained file: the
# tower data is embedded as JSON (data, never code), so it also opens straight
# from disk. Leaflet and the OpenStreetMap tiles load from the web.
#
# The classification lives in analysis/_common.R, so this script sources it.
# That keeps one definition of the types: the map always shows what the
# chapters show. Re-run after changing _common.R or re-running script 08.
#
# Contents: frame towers, plus unringable rings shown faded (Mark,
# 2026-10-11), so volunteers can see every tower with bells when judging
# city cores. Unringable rings are outside the frame (D-002) and play no part
# in any other tower's type; each is given the type its own place would
# have, by the same rule. Place measures, bells, type, and a known tower's
# "feels like" where one is recorded. No personal data: known_by is not
# exported.

source(here::here("scripts", "00_setup.R"))
source(here::here("analysis", "_common.R"))   # frame_towers, Draft B, known

TEMPLATE <- here::here("inst", "settlement_map", "map_template.html")
OUT_DIR  <- here::here("docs", "settlement-map")
MAX_BYTES <- 1048576   # the pre-commit hook blocks files over 1 MiB

# Colours: the chapters' palette, one per type, in TYPE_LEVELS order.
type_colours <- unname(PAL_TYPE[TYPE_LEVELS])

# Unringable rings: one per tower, skipping the few towers that also have a
# ringable ring (they are on the map already). Measures come from the same
# context table. Other towers' bells within 1 km: bells_r1km counts frame
# towers only, and an unringable tower is never one, so nothing is
# subtracted.
unringable <- frame |>
  dplyr::filter(!.data$is_ringable, !.data$tower_id %in% towers$tower_id) |>
  dplyr::summarise(bells = max(.data$bells), display = dplyr::first(.data$display),
                   .by = "tower_id") |>
  dplyr::inner_join(locations, by = "tower_id") |>
  dplyr::inner_join(context |> dplyr::select(-"in_frame"), by = "tower_id") |>
  dplyr::left_join(
    special |> dplyr::distinct(.data$tower_id, .keep_all = TRUE) |>
      dplyr::select("tower_id", special = "category"),
    by = "tower_id"
  ) |>
  dplyr::mutate(
    society = !is.na(.data$special) & .data$special %in% SOCIETY_CATEGORIES,
    other_bells_1km = .data$bells_r1km,
    centre_key = ifelse(is.na(.data$centre_pop), NA_character_,
                        paste(round(.data$centre_pop), .data$centre_km2)),
    type = classify_settlement_b(.data$centre_pop, .data[[LOCAL_VAR]], .data[[INNER_VAR]],
                                 .data$other_bells_1km, .data$society, DRAFT_B, TYPE_LEVELS)
  )
n_unringable_no_context <- sum(!frame$is_ringable) - nrow(unringable) -
  sum(!frame$is_ringable & frame$tower_id %in% towers$tower_id)
message(nrow(unringable), " unringable rings mapped; ", n_unringable_no_context,
        " have no context row and are left off.")
shown <- dplyr::bind_rows(
  frame_towers |> dplyr::mutate(ur = 0L),
  unringable   |> dplyr::mutate(ur = 1L)
)

# Urban centres go in a lookup table, so each tower carries a small index
# rather than repeating its centre's figures (the page must stay under 1 MiB).
centres <- shown |>
  dplyr::filter(!is.na(.data$centre_key)) |>
  dplyr::distinct(.data$centre_key, .data$centre_pop) |>
  dplyr::mutate(centre = dplyr::row_number() - 1L)

rows <- shown |>
  dplyr::left_join(known |> dplyr::select("tower_id", "feels_like"), by = "tower_id") |>
  dplyr::left_join(centres |> dplyr::select("centre_key", "centre"), by = "centre_key") |>
  dplyr::transmute(
    lat   = round(.data$lat, 4),                    # about 10 m
    lon   = round(.data$lon, 4),
    label = .data$display,
    bells = .data$bells,
    type  = as.integer(.data$type) - 1L,            # 0-based for JavaScript
    density = signif(.data[[LOCAL_VAR]], 3),         # 500 m kernel
    district = signif(.data[[INNER_VAR]], 3),        # 1 km kernel
    centre = .data$centre,
    other_bells = .data$other_bells_1km,
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
