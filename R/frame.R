# frame.R ---------------------------------------------------------------------
#
# Frame construction helpers.
#
# The frame is the set of rings the census measures. Membership is carried as
# FLAGS, not as a filter (D-006): the curated table holds one row per ring with
# a boolean column per frame definition, so an analysis picks its denominator
# explicitly rather than inheriting one from a filter several scripts upstream.
#
# See provenance/decisions.md for the reasoning behind each rule.

#' Countries counted as the British Isles
#'
#' Used for the 1988-comparable frame. 1988's own frame was "towers with five
#' or more bells in the British Isles"; Dove holds "Island of Ireland" as a
#' single undivided country, which suits this purpose.
BRITISH_ISLES <- c(
  "England", "Wales", "Scotland",
  "Island of Ireland", "Channel Islands", "Isle of Man"
)

#' Add frame membership flags to a staged Dove table
#'
#' Expects the snake_case column names produced by `scripts/04_build_frame.R`,
#' not Dove's own PascalCase. Renaming happens once, in the script.
#'
#' @param dove Tibble with at least `ur`, `ring_type`, `country`, `bells`.
#' @param volunteer_countries Countries outside the British Isles included in
#'   the sampling frame because a volunteer is present there (D-019). Read from
#'   data/reference/frame_countries_with_volunteers.csv - never hard-coded.
#' @return The input with flag columns added.
add_frame_flags <- function(dove, volunteer_countries) {
  dove |>
    dplyr::mutate(
      # D-002: a ring that cannot be rung cannot have been rung in the
      # reference week.
      is_ringable   = is.na(.data$ur) | .data$ur != "u/r",

      # D-003/D-018: mini-rings are excluded from the sampling frame but
      # included in the picker. Every ring with a blank DoveID is a mini-ring.
      is_fullcircle = .data$ring_type == "Full-circle ring",

      is_british_isles = .data$country %in% BRITISH_ISLES,

      is_volunteer_country = .data$country %in% volunteer_countries,

      # The sampling frame. D-017 (Agreed 2026-09-20): four or more bells.
      # D-019 (Agreed 2026-09-20): British Isles, plus countries where a
      # volunteer is present. D-002, D-003: ringable, full-circle.
      frame_full = .data$is_ringable & .data$is_fullcircle &
                   .data$bells >= 4 &
                   (.data$is_british_isles | .data$is_volunteer_country),

      # The 1988 frame, reconstructed: five or more bells, British Isles.
      # Applying this to the 2026-09-19 snapshot gives 5,473 against 1988's
      # stated 5,425 — 0.9% apart, which is the evidence that the rule is
      # right.
      frame_1988 = .data$frame_full &
                   .data$bells >= 5 &
                   .data$is_british_isles,

      # D-018 (Agreed 2026-09-20), superseding D-008: the picker is BROADER
      # than the frame. Every ringable ring - rings of three and mini-rings
      # included - so anyone ringing somewhere real can find it, while the
      # sampling frame stays at 4+ full-circle. Frame and picker are flags on
      # the same table (D-006), which is what makes this split cheap.
      frame_picklist = .data$is_ringable
    )
}

#' Build the respondent-facing display string for a ring
#'
#' Form: "<place>, <dedication> (<bells>) — <county>[, <country>]"
#'
#' Three wrinkles in Dove that this handles, all found by inspection of the
#' 2026-09-19 snapshot:
#'
#'   * `PlaceCL` is already a composed display string where it is populated
#'     (763 rows), e.g. "Abbots Bromley, The Campanile". Using it AND the
#'     dedication duplicates the dedication. Where PlaceCL is present it is
#'     used alone as the place part.
#'   * 61 rings have no `Dedicn`. `RingName` is the fallback; where both are
#'     empty the place stands alone.
#'   * Some rings have no county, which would otherwise leave a dangling
#'     separator.
#'
#' Bell count is included because without it the frame contains 16 colliding
#' rows; with it, 2 (D-009 and the collision analysis).
#'
#' @return Character vector.
build_display <- function(place, place_cl, dedication, ring_name, bells,
                          county, country, is_mini = FALSE) {
  blank <- \(x) is.na(x) | trimws(x) == ""

  place_part <- dplyr::if_else(blank(place_cl), place, place_cl)

  ded <- dplyr::case_when(
    !blank(dedication) ~ dedication,
    !blank(ring_name)  ~ ring_name,
    TRUE               ~ NA_character_
  )

  # Suppress a dedication already contained in the place part, which is what
  # PlaceCL rows would otherwise produce.
  ded <- dplyr::if_else(
    !is.na(ded) & stringr::str_detect(place_part, stringr::fixed(ded)),
    NA_character_, ded
  )

  where <- dplyr::case_when(
    blank(county) & blank(country)     ~ NA_character_,
    blank(county)                      ~ country,
    country %in% BRITISH_ISLES         ~ county,
    TRUE                               ~ paste0(county, ", ", country)
  )

  out <- place_part
  out <- dplyr::if_else(is.na(ded),   out, paste0(out, ", ", ded))
  # D-020: mini-rings are marked everywhere, not only where two rings would
  # otherwise collide - a respondent should never mistake one for the other.
  out <- paste0(out, " (", bells, dplyr::if_else(is_mini, ", mini-ring", ""), ")")
  out <- dplyr::if_else(is.na(where), out, paste0(out, " — ", where))
  out
}
