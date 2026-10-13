# towers.R ---------------------------------------------------------------------
#
# The tower table and its settlement classification, shared by
# scripts/B05_build_tower_classes.R (which saves the classification) and
# analysis/_common.R (which explores it). One definition, so the chapters,
# the volunteers' map and the sample draw cannot disagree about a tower's
# type.
#
# CONTRACT: as for everything in R/, these functions take explicit inputs and
# return values. They do not read or write files. The choices they apply are
# passed in by the caller from config/choices.R.

#' One row per tower with a ringable full-circle ring of 3 or more bells
#'
#' Joins the frame to the tower's location, settlement context, retail
#' distances and special-list category. `in_frame` marks the sampling frame.
#'
#' Towers whose density_var is zero or missing are DROPPED (their log density
#' is not finite). This filter was in analysis/_common.R before 13 October
#' 2026 and is kept unchanged; it removes a tower from the classification
#' altogether, so it is a methodological choice worth reviewing.
#'
#' @param multi_ring_bells "max" or "sum": bells at a tower with two rings (Q-020).
#' @param society_categories Special-list categories counted as society or
#'   city-core towers (Q-022).
#' @param density_var,tight_var,region_var Context columns used for log
#'   density and isolation.
assemble_towers <- function(frame, locations, context, retail, special,
                            multi_ring_bells, society_categories,
                            density_var, tight_var, region_var) {
  frame |>
    dplyr::filter(.data$is_ringable, .data$is_fullcircle, .data$bells >= 3) |>
    dplyr::summarise(
      bells    = if (multi_ring_bells == "max") max(.data$bells) else sum(.data$bells),
      in_frame = any(.data$frame_full),
      country  = dplyr::first(.data$country),
      county   = dplyr::first(.data$county),
      display  = dplyr::first(.data$display),
      .by = "tower_id"
    ) |>
    join_tower_context(locations, context, retail, special) |>
    dplyr::mutate(
      ld         = log10(.data[[density_var]]),
      # +1 person per km2 keeps places with nobody within the tight kernel
      # finite; it is negligible anywhere people live.
      isolation  = log10((.data[[tight_var]] + 1) / (.data[[region_var]] + 1)),
      coast      = 1 - .data$land_share_k8km,
      society    = !is.na(.data$special) & .data$special %in% society_categories,
      # Bells within 1 km at OTHER frame towers. bells_r1km counts frame towers
      # only, so a frame tower's own bells are subtracted; others never counted.
      other_bells_1km = .data$bells_r1km - ifelse(.data$in_frame, .data$bells, 0),
      # People within reach by car but beyond walking distance (D-037).
      beyond_walk = beyond_walk(.data$pop_k2km, .data$pop_k250m,
                                .data$land_km2_k2km, .data$land_km2_k250m),
      # Frame towers within 1 km, the tower itself included. towers_r1km counts
      # frame towers only, so a tower outside the frame adds itself.
      towers_1km = .data$towers_r1km + ifelse(.data$in_frame, 0, 1),
      british_isles = .data$country %in% BRITISH_ISLES,
      uk = is_uk(.data$country, .data$county)
    ) |>
    dplyr::filter(is.finite(.data$ld))
}

#' One row per tower that has only unringable rings
#'
#' For the volunteers' map, which shows them faded (Mark, 2026-10-11).
#' Unringable rings are outside the frame (D-002) and play no part in any
#' other tower's type. Towers that also have a ringable ring are skipped
#' (exclude_ids): they appear in assemble_towers() already. towers_r1km counts
#' frame towers only, so an unringable ring is never counted, by itself or by
#' anyone else.
assemble_unringable <- function(frame, locations, context, retail, special,
                                society_categories, exclude_ids) {
  frame |>
    dplyr::filter(!.data$is_ringable, !.data$tower_id %in% exclude_ids) |>
    dplyr::summarise(bells   = max(.data$bells),
                     display = dplyr::first(.data$display),
                     country = dplyr::first(.data$country),
                     county  = dplyr::first(.data$county),
                     .by = "tower_id") |>
    join_tower_context(locations, context, retail, special) |>
    dplyr::mutate(
      in_frame   = FALSE,
      uk         = is_uk(.data$country, .data$county),
      society    = !is.na(.data$special) & .data$special %in% society_categories,
      towers_1km = .data$towers_r1km,
      beyond_walk = beyond_walk(.data$pop_k2km, .data$pop_k250m,
                                .data$land_km2_k2km, .data$land_km2_k250m)
    )
}

#' Draft C settlement type, tower-cluster flag and 1988 type for each tower
#'
#' @param eligible May each tower be its settlement's fallback centre? Default:
#'   frame towers only, so towers outside the frame never change the result
#'   for those in it. FALSE for unringable rings.
#' @param th Draft C thresholds (DRAFT_C in config/choices.R).
#' @param crosswalk Named vector mapping each type to one of 1988's five.
classify_towers <- function(towers, local_var, nres_var, th, levels, crosswalk,
                            eligible = towers$in_frame) {
  towers |>
    dplyr::mutate(
      # An identifier for each urban centre (its population and area together),
      # and its average density (people per km2 of its 1 km cells).
      centre_key = ifelse(is.na(.data$centre_pop), NA_character_,
                          paste(round(.data$centre_pop), .data$centre_km2)),
      centre_density = .data$centre_pop / .data$centre_km2,
      # The non-residential share round the church against its whole urban
      # centre's: above 1, more commercial than its town as a whole.
      nres_ratio = .data[[nres_var]] / .data$centre_nres_share,
      # On or by a high street (UK only; NA abroad, where retail centres are not
      # mapped and the non-residential share is used instead).
      retail_near = retail_near(dplyr::pick(dplyr::starts_with("retail_d_t")), th),
      type = classify_settlement_c(.data$centre_key, .data$centre_pop, .data[[local_var]],
                                   .data$retail_near, .data$nres_ratio, .data$towers_1km,
                                   eligible, th, levels),
      tower_cluster = tower_cluster(.data$towers_1km, .data$society, th),
      # 1988's five types. Tower clusters go to "Large City": 1988's type of the
      # great city-centre churches, with the most ringers per bell.
      type_1988 = ifelse(.data$tower_cluster, "Large City",
                         unname(crosswalk[as.character(.data$type)]))
    )
}

# People per km2 of land within reach by car but beyond walking distance: the
# 2 km kernel with the 250 m kernel's people and land taken out (D-037).
beyond_walk <- function(pop_2km, pop_250m, land_2km, land_250m) {
  (pop_2km - pop_250m) / (land_2km - land_250m)
}

# The UK: Great Britain plus the six counties of Northern Ireland (Dove files
# the whole island of Ireland as one country).
is_uk <- function(country, county) {
  country %in% c("England", "Wales", "Scotland") |
    (country == "Island of Ireland" &
       county %in% c("Antrim", "Armagh", "Down", "Fermanagh", "Derry",
                     "Londonderry", "Tyrone"))
}

join_tower_context <- function(x, locations, context, retail, special) {
  x |>
    dplyr::inner_join(locations, by = "tower_id") |>
    dplyr::inner_join(context |> dplyr::select(-"in_frame"), by = "tower_id") |>
    dplyr::left_join(retail, by = "tower_id") |>
    dplyr::left_join(
      special |> dplyr::distinct(.data$tower_id, .keep_all = TRUE) |>
        dplyr::select("tower_id", special = "category"),
      by = "tower_id"
    )
}
