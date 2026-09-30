# 04_build_frame.R ------------------------------------------------------------
#
# Build the curated ring frame from a named Dove snapshot.
#
# Output: data/curated/frame_<snapshot_id>.parquet, plus a .json sidecar
# recording the snapshot and script that produced it.
#
# The snapshot is NAMED, not discovered. Nothing here silently picks "the
# latest" — the frame must be a stated, frozen snapshot or the denominator
# moves under the analysis.
#
# NOTE: script 03 (society crosswalk) is deliberately not written yet. It is
# not needed for the questionnaire picklist and is blocked on Q-006.

source(here::here("scripts", "00_setup.R"))

# ---- choose the snapshot ----------------------------------------------------

SNAPSHOT_ID <- "dove_2026-09-19"          # <- change deliberately, never silently

# D-019: international countries in the frame are those with a volunteer
# present. The list is committed reference data with an owner, not a vector
# buried in code.
volunteer_countries <- readr::read_csv(
  here::here("data", "reference", "frame_countries_with_volunteers.csv"),
  show_col_types = FALSE
) |>
  dplyr::pull(country)

snap <- fs::path(here::here("data", "raw", "dove"),
                 sub("^dove_", "", SNAPSHOT_ID))
stopifnot(fs::dir_exists(snap))

# Verify the bytes are the ones recorded. A frame built from an edited or
# half-downloaded snapshot is worse than no frame.
log_rows <- read_fetch_log() |> dplyr::filter(.data$snapshot_id == SNAPSHOT_ID)
stopifnot(nrow(log_rows) > 0)
purrr::pwalk(
  log_rows |> dplyr::select(file, sha256),
  \(file, sha256) verify_sha256(fs::path(snap, file), sha256)
)
message("Checksums verified for ", SNAPSHOT_ID)

# ---- read -------------------------------------------------------------------
#
# Read everything as character, then convert deliberately. Letting readr guess
# would silently coerce, and Dove warns its field order may change — so every
# column is taken by name.

dove_raw <- readr::read_csv(
  fs::path(snap, "dove.csv"),
  col_types = readr::cols(.default = "c"),
  # Dove's file carries a UTF-8 BOM on the first header.
  locale = readr::locale(encoding = "UTF-8")
)

message("Read ", format(nrow(dove_raw), big.mark = ","), " rows")

# ---- select and rename ------------------------------------------------------

dove <- dove_raw |>
  dplyr::transmute(
    ring_id      = .data$RingID,
    tower_id     = .data$TowerID,
    dove_id      = dplyr::na_if(.data$DoveID, ""),
    ring_type    = .data$RingType,
    place        = .data$Place,
    place_cl     = dplyr::na_if(.data$PlaceCL, ""),
    dedication   = dplyr::na_if(.data$Dedicn, ""),
    ring_name    = dplyr::na_if(.data$RingName, ""),
    alt_name     = dplyr::na_if(.data$AltName, ""),
    county       = dplyr::na_if(.data$County, ""),
    country      = .data$Country,
    region       = dplyr::na_if(.data$Region, ""),
    diocese      = dplyr::na_if(.data$Diocese, ""),
    bells        = as.integer(.data$Bells),
    ur           = dplyr::na_if(.data$UR, ""),
    affiliations = dplyr::na_if(.data$Affiliations, ""),
    lat          = as.numeric(.data$Lat),
    long         = as.numeric(.data$Long),
    postcode     = dplyr::na_if(.data$Postcode, "")
  )

# RingID is the key (D-007). TowerID is not unique — 13 towers hold two rings —
# and DoveID is blank for 118 lightweight rings.
stopifnot(!any(duplicated(dove$ring_id)))
stopifnot(!any(is.na(dove$bells)))

# ---- flags, display, search key ---------------------------------------------

frame <- dove |>
  add_frame_flags(volunteer_countries) |>
  dplyr::mutate(
    display = build_display(
      place      = .data$place,
      place_cl   = .data$place_cl,
      dedication = .data$dedication,
      ring_name  = .data$ring_name,
      bells      = .data$bells,
      county     = .data$county,
      country    = .data$country,
      is_mini    = .data$ring_type == "Lightweight ring"
    ),
    # Alternative names carry what people actually call the place — "Exmouth"
    # for Withycombe Raleigh. They belong in the search key, never the display.
    # Dove delimits multiples with semicolons.
    alt_terms = stringr::str_replace_all(
      tidyr::replace_na(.data$alt_name, ""), ";", " "
    ) |> stringr::str_squish(),

    search_key = build_search_key(.data$display, .data$alt_terms)
  )

# ---- checks -----------------------------------------------------------------

# Expected on dove_2026-09-19: 7262 / 6297 / 5743 / 114 / 5473.
counts <- tibble::tibble(
  rule = c("all rows", "frame_picklist (all ringable)", "frame_full",
           "  of which volunteer countries", "frame_1988"),
  n = c(
    nrow(frame),
    sum(frame$frame_picklist),
    sum(frame$frame_full),
    sum(frame$frame_full & frame$is_volunteer_country),
    sum(frame$frame_1988)
  )
)
print(counts)

# 1988's own frame was 5,425 towers. A large divergence here means either the
# rule has drifted or Dove has changed materially — either way, stop and look.
n_1988 <- sum(frame$frame_1988)
message(sprintf(
  "\nframe_1988 = %d against 1988's stated 5,425 (%+.1f%%)",
  n_1988, 100 * (n_1988 - 5425) / 5425
))
if (abs(n_1988 - 5425) / 5425 > 0.05) {
  warning("frame_1988 is more than 5% from the 1988 figure. Investigate before proceeding.")
}

# Display strings must be unique within the picklist: a duplicate entry is
# unusable, because the respondent cannot tell which one is theirs.
dups <- frame |>
  dplyr::filter(.data$frame_picklist) |>
  find_duplicate_displays(display_col = "display", id_col = "ring_id")

if (nrow(dups) > 0) {
  message("\n", nrow(dups), " colliding display strings in the picklist:")
  print(dups |> dplyr::select(ring_id, tower_id, display, bells))
  message("Expected: none. The mini-ring marker (D-020) separates Farnham's two rings of ten.")
}

# ---- write ------------------------------------------------------------------

out <- fs::path(here::here("data", "curated"),
                paste0("frame_", SNAPSHOT_ID, ".parquet"))

write_artefact(
  frame,
  path        = out,
  snapshot_id = SNAPSHOT_ID,
  script      = "scripts/04_build_frame.R"
)

message("\nWrote ", out)
message("Next: scripts/05_export_questionnaire_towers.R")
