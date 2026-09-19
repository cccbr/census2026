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
#' @return The input with flag columns added.
add_frame_flags <- function(dove) {
  dove |>
    dplyr::mutate(
      # D-002: a ring that cannot be rung cannot have been rung in the
      # reference week.
      is_ringable   = is.na(.data$ur) | .data$ur != "u/r",

      # D-003: mini-rings are excluded. Note this also removes every ring with
      # a blank DoveID — the two criteria select the same rows.
      is_fullcircle = .data$ring_type == "Full-circle ring",

      is_british_isles = .data$country %in% BRITISH_ISLES,

      # D-001/002/003/005. No bell minimum, all countries. D-004 stays open,
      # which the flags approach permits.
      frame_full = .data$is_ringable & .data$is_fullcircle,

      # The 1988 frame, reconstructed: five or more bells, British Isles.
      # Applying this to the 2026-09-19 snapshot gives 5,473 against 1988's
      # stated 5,425 — 0.9% apart, which is the evidence that the rule is
      # right.
      frame_1988 = .data$frame_full &
                   .data$bells >= 5 &
                   .data$is_british_isles,

      # D-008: the questionnaire picklist is the frame exactly, plus a
      # free-text escape offered in the widget rather than as a frame row.
      frame_picklist = .data$frame_full
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
                          county, country) {
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
  out <- paste0(out, " (", bells, ")")
  out <- dplyr::if_else(is.na(where), out, paste0(out, " — ", where))
  out
}
