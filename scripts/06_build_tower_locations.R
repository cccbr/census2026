# 06_build_tower_locations.R --------------------------------------------------
#
# Build a minimal location table, one row per Dove tower, from the curated
# frame. Geographic enrichment (scripts/08) hangs off this table and joins back
# to the frame on tower_id when needed.
#
# WHY TOWER, NOT RING
#   Location is a property of the tower. The 13 two-ring towers share one site,
#   so their context is the same. The frame key is still RingID (D-007): join
#   frame -> context on tower_id.
#
# Output: data/curated/tower_locations_<snapshot_id>.parquet (+ .json sidecar)

source(here::here("scripts", "00_setup.R"))

SNAPSHOT_ID <- "dove_2026-09-19"          # <- change deliberately, never silently

frame <- arrow::read_parquet(
  here::here("data", "curated", paste0("frame_", SNAPSHOT_ID, ".parquet"))
)

# ---- one row per tower ------------------------------------------------------

locations <- frame |>
  dplyr::distinct(.data$tower_id, .data$lat, .data$long) |>
  dplyr::rename(lon = "long")

# A tower with two different coordinates would mean Dove places its rings
# apart. We want to know about that, not average it away.
stopifnot(!any(duplicated(locations$tower_id)))

n_missing <- sum(is.na(locations$lat) | is.na(locations$lon))
message(n_missing, " towers without coordinates")

# On dove_2026-09-19 no frame ring lacks coordinates. If one appears in a later
# snapshot, Dove's NG grid reference is the obvious fallback. That would be a
# decision, so it is not done silently here.
missing_in_frame <- frame |>
  dplyr::filter(.data$frame_full, is.na(.data$lat) | is.na(.data$long))
if (nrow(missing_in_frame) > 0) {
  warning(nrow(missing_in_frame), " frame rings lack coordinates. ",
          "Decide a fallback before enriching.")
}

# ---- evidence for the kernel half-distances (Q-019) --------------------------
#
# Nearest-neighbour distance between frame towers is the natural yardstick for
# "local". It is printed here, not used, because choosing the half-distance is
# Q-019 and not this script's job.

frame_towers <- frame |>
  dplyr::filter(.data$frame_full) |>
  dplyr::distinct(.data$tower_id, .data$lat, .data$long, .data$country)

nn_km <- purrr::map_dbl(seq_len(nrow(frame_towers)), \(i) {
  d <- haversine_m(frame_towers$long[i], frame_towers$lat[i],
                   frame_towers$long[-i], frame_towers$lat[-i])
  min(d) / 1000
})

frame_towers |>
  dplyr::mutate(
    nn_km = nn_km,
    group = dplyr::if_else(.data$country %in% c("England", "Wales"),
                           "England & Wales", "Elsewhere")
  ) |>
  dplyr::summarise(
    towers = dplyr::n(),
    p10 = stats::quantile(.data$nn_km, 0.10),
    p25 = stats::quantile(.data$nn_km, 0.25),
    p50 = stats::quantile(.data$nn_km, 0.50),
    p75 = stats::quantile(.data$nn_km, 0.75),
    p90 = stats::quantile(.data$nn_km, 0.90),
    .by = "group"
  ) |>
  print()

# ---- write ------------------------------------------------------------------

out <- here::here("data", "curated",
                  paste0("tower_locations_", SNAPSHOT_ID, ".parquet"))

write_artefact(
  locations,
  path        = out,
  snapshot_id = SNAPSHOT_ID,
  script      = "scripts/06_build_tower_locations.R"
)

message("Wrote ", out, "\nNext: scripts/07_fetch_geography.R")
