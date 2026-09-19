# text.R ----------------------------------------------------------------------
#
# Text normalisation for tower matching and autocomplete search.
#
# WHY THIS EXISTS
#   Ringers may type the way they speak, not the way Dove spells. Dove writes
#   "S Mary the Virgin"; a ringer types "st marys", "saint mary", "St. Mary's".
#   A naive substring match on the display string fails all three. The fix is a
#   normalised *search key* held alongside the display string: the widget
#   matches on the key, shows the display.
#
# This is deliberately separate from the display string. Never show a search
# key to a human and never match on a display string.

#' Normalise a string to a search key
#'
#' Applied to both the stored key and the user's typed input, so the two meet
#' in the middle.
#'
#' Transformations, in order:
#'   1. Transliterate to ASCII      Ynys Môn -> Ynys Mon
#'   2. Lowercase
#'   3. "&" -> " and "
#'   4. Fold saint forms            saint / s / ss / s. / ss. -> st
#'   5. Drop apostrophes entirely   st mary's -> st marys  (not "st mary s")
#'   6. Other punctuation -> space
#'   7. Collapse whitespace, trim
#'
#' Note on step 4: Dove uses "S" for a single saint and "SS" for joint
#' dedications ("SS Peter & Paul"). Both fold to "st" so that a searcher typing
#' "st peter" finds "SS Peter and Paul". The \\b anchors mean "street" and
#' similar are untouched.
#'
#' @param x Character vector.
#' @return Character vector of the same length.
normalise_search_key <- function(x) {
  x |>
    stringi::stri_trans_general("Latin-ASCII") |>
    tolower() |>
    stringr::str_replace_all("&", " and ") |>
    stringr::str_replace_all("\\bsaints?\\b", "st") |>
    stringr::str_replace_all("\\bss?\\.?(?=\\s|$)", "st") |>
    stringr::str_remove_all("['’]") |>
    stringr::str_replace_all("[^a-z0-9]+", " ") |>
    stringr::str_squish()
}

#' Build the search key for a tower from its components
#'
#' Concatenating place, dedication and county into one key means a single
#' substring match handles "st mary oxford" and "oxford st mary" equally — the
#' widget should tokenise the query and require all tokens present, rather than
#' matching the query as one substring.
#'
#' @param ... Character vectors of equal length (place, dedication, county, ...).
#' @return Character vector.
build_search_key <- function(...) {
  parts <- list(...)
  parts <- lapply(parts, \(p) ifelse(is.na(p), "", as.character(p)))
  do.call(paste, c(parts, list(sep = " "))) |>
    normalise_search_key()
}

#' Flag duplicate display strings
#'
#' A display string that appears twice is unusable in a picklist: the respondent
#' cannot tell which one is theirs, and whichever they pick is a coin flip. Run
#' this before export and disambiguate every hit — usually by appending the
#' county, the dedication, or the bell count.
#'
#' @return Tibble of the offending rows, empty if clean.
find_duplicate_displays <- function(
  df,
  display_col = "display",
  id_col = "dove_id"
) {
  df |>
    dplyr::add_count(.data[[display_col]], name = "n_with_display") |>
    dplyr::filter(.data$n_with_display > 1) |>
    dplyr::arrange(.data[[display_col]], .data[[id_col]])
}
