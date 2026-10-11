# _common.R --------------------------------------------------------------------
#
# Shared set-up for the settlement chapters (tower-context, settlement-classes,
# sampling-design). Each chapter sources this after scripts/00_setup.R, so all
# three use the same data, the same provisional choices and the same
# classification.
#
# FREEZE WARNING. Quarto's freeze re-runs a chapter only when the chapter's own
# .qmd changes. It does not notice changes to this file. After editing it,
# render each chapter on its own (quarto render analysis/<chapter>.qmd),
# which always re-runs the code, or delete analysis/_freeze/ and render the
# book. --cache-refresh does NOT clear the freeze.
#
# The leading underscore stops Quarto treating this file as a chapter.

FRAME_SNAPSHOT <- "dove_2026-09-19"   # <- named, never discovered

# ---- choices, all provisional ------------------------------------------------
# Starting points for the analytical team to calibrate. None is a decision.

MULTI_RING_BELLS <- "max"                   # Q-020, open

# Density measures, all people per km2 of LAND so the sea does not count as
# empty.
#   DENSITY_VAR: used to study ring size against density (2 km kernel).
#   LOCAL_VAR:   the tower's own place: people per km2 of LAND in the 250 m
#                kernel. One local measure for every density line in the
#                classification (town, village, inner city, small-city
#                suburb). Kernels throughout (Mark, 2026-10-11), except the
#                historic-city-core test, where a crisp 1 km circle suits a
#                compact cluster of towers. Densities, not counts, so the
#                lines compare with the Degree of Urbanisation's 300 and
#                1,500 per km2 (Mark, 2026-10-11).
#   REGION_VAR:  the wider region (8 km kernel).
DENSITY_VAR   <- "density_land_k2km"
LOCAL_VAR     <- "density_land_k250m"
REGION_VAR    <- "density_land_k8km"
DRAFT_A_LOCAL_VAR <- "density_land_r1km"   # Draft A as it was, for comparison

# Ring-size classes. Rings of 3 are outside the frame (4+ bells) but are used
# in the structure analysis, because they say what sort of place has a small
# ring.
RING_BREAKS <- c(2.5, 3.5, 5.5, 7.5, 9.5, Inf)
RING_LABELS <- c("3", "4-5", "6-7", "8-9", "10+")

# Draft A thresholds (superseded as the working draft; kept for comparison).
#   town: local density >= 300 per km2, and >= 5,000 people within 2 km
#   city or large town: local density >= 1,500, and >= 50,000 within 5 km
#   region: built-up at or above 1,000 per km2 in the 8 km kernel
DRAFT_A <- list(town_density = 300, town_pop = 5000,
                city_density = 1500, city_pop = 50000,
                region_density = 1000)

# Draft B thresholds: the working draft. See R/settlement.R. Every density
# is people per km2 of LAND in the 250 m kernel (LOCAL_VAR).
#   core_other_bells: a tower inside an urban centre with at least this many
#     bells at OTHER frame towers within 1 km is in a historic city core
#     (D-031). 30 is about four rings of eight.
#   conurbation_pop: an urban centre this size or larger is a conurbation.
#     Set in a gap in UK centre sizes (Nottingham 636k | Leicester 513k), so
#     small data changes cannot move a city across it; keeps Bristol in.
#   inner_density: the inner-city line within a conurbation. 5,000 (Mark,
#     2026-10-11): at 8,000 almost only London qualified. Aligning with 1988
#     is a high priority (Mark), and 1988's inner city was in every major
#     conurbation.
#   town_density: a town outside an urban centre. Best match to 1988's share
#     of towns.
#   village_density: below this, a small village or hamlet. 300 per km2 is
#     the Degree of Urbanisation's own density for a cluster, rural or urban.
#   small_city_suburbs (adopted 2026-10-11, Mark): in a smaller city, a tower is
#     suburban if its density is below its city's average density AND it has
#     fewer than suburb_core_bells bells at other towers within 1 km. Uses
#     only density and bell density; no centre point.
DRAFT_B <- list(core_other_bells = 30, conurbation_pop = 575000,
                inner_density = 5000, town_density = 600, village_density = 300,
                small_city_suburbs = TRUE, suburb_core_bells = 12)
INNER_VAR <- LOCAL_VAR

# Special-list categories treated as "society or city-core" towers (Q-022).
SOCIETY_CATEGORIES <- c("society_steeple_keeper", "city_of_london_other",
                        "central_london_major")

set.seed(20261116)   # reference week; any fixed seed would do

# ---- palette (validated reference palette, fixed slot order) ----------------
PAL_CAT <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
             "#e87ba4", "#008300", "#6250d6", "#e34948")
RING_PAL <- stats::setNames(c("#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"),
                            RING_LABELS)
# Ordinal blue ramp for the Degree of Urbanisation, light (rural) to dark.
PAL_SMOD <- c("Very low density rural"   = "#86b6ef",
              "Low density rural"        = "#5598e7",
              "Rural cluster"            = "#2a78d6",
              "Suburban or peri-urban"   = "#256abf",
              "Semi-dense urban cluster" = "#1c5cab",
              "Dense urban cluster"      = "#184f95",
              "Urban centre"             = "#0d366b",
              "Water"                    = "#9a9a9a")
TYPE_LEVELS <- c("Small village or hamlet", "Village", "Town",
                 "City or large town", "Suburban", "Inner city",
                 "Historic city core")
# Historic city core in near-black, so it stands apart from the warm town
# and city colours on maps.
PAL_TYPE <- stats::setNames(c(PAL_CAT[c(3, 1, 4, 2, 5, 7)], "#222222"), TYPE_LEVELS)
TYPE_LEVELS_A <- c("Village", "Village in a built-up region",
                   "Town", "Town in a built-up region",
                   "City or large town", "City or large town in a conurbation",
                   "Society or city-core tower")

ggplot2::theme_set(
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major = ggplot2::element_line(linewidth = 0.25, colour = "grey88"),
                   legend.position = "bottom",
                   plot.title.position = "plot")
)
fmt <- scales::label_comma(accuracy = 1)
pct <- scales::label_percent(accuracy = 1)

# ---- data -------------------------------------------------------------------
cur <- \(stem) here::here("data", "curated", paste0(stem, "_", FRAME_SNAPSHOT, ".parquet"))
frame     <- arrow::read_parquet(cur("frame"))
context   <- arrow::read_parquet(cur("tower_context"))
locations <- arrow::read_parquet(cur("tower_locations"))
special   <- readr::read_csv(
  here::here("data", "reference", "special_towers_draft.csv"),
  col_types = readr::cols(.default = "c")
)
known     <- readr::read_csv(
  here::here("data", "reference", "known_towers.csv"),
  col_types = readr::cols(.default = "c")
)

# The new measures from script 08 (2026-10-10). Stop early, with a clear
# message, if the context table predates them.
needed_cols <- c("density_land_k250m", "density_land_k500m", "density_land_r500m",
                 "centre_pop", "urban_pop", "rural_cluster_pop", "centre_dist_km")
missing_cols <- setdiff(needed_cols, names(context))
if (length(missing_cols) > 0) {
  stop("The tower context table is missing ", paste(missing_cols, collapse = ", "),
       ". Re-run scripts/08_build_tower_context.R.", call. = FALSE)
}

# One row per tower with a ringable full-circle ring of 3 or more bells, in
# any country that has frame towers. `in_frame` marks the sampling frame.
towers <- frame |>
  dplyr::filter(.data$is_ringable, .data$is_fullcircle, .data$bells >= 3) |>
  dplyr::summarise(
    bells    = if (MULTI_RING_BELLS == "max") max(.data$bells) else sum(.data$bells),
    in_frame = any(.data$frame_full),
    country  = dplyr::first(.data$country),
    county   = dplyr::first(.data$county),
    display  = dplyr::first(.data$display),
    .by = "tower_id"
  ) |>
  dplyr::inner_join(locations, by = "tower_id") |>
  dplyr::inner_join(context |> dplyr::select(-"in_frame"), by = "tower_id") |>
  dplyr::left_join(
    special |> dplyr::distinct(.data$tower_id, .keep_all = TRUE) |>
      dplyr::select("tower_id", special = "category"),
    by = "tower_id"
  ) |>
  dplyr::mutate(
    ring_class = cut(.data$bells, RING_BREAKS, RING_LABELS),
    ld         = log10(.data[[DENSITY_VAR]]),
    # +1 person per km2 keeps places with nobody within the tight kernel
    # finite; it is negligible anywhere people live.
    isolation  = log10((.data[[LOCAL_VAR]] + 1) / (.data[[REGION_VAR]] + 1)),
    coast      = 1 - .data$land_share_k8km,
    society    = !is.na(.data$special) & .data$special %in% SOCIETY_CATEGORIES,
    # Bells within 1 km at OTHER frame towers. bells_r1km counts frame towers
    # only, so a frame tower's own bells are subtracted; others never counted.
    other_bells_1km = .data$bells_r1km - ifelse(.data$in_frame, .data$bells, 0),
    smod_class = factor(.data$smod_class, levels = names(PAL_SMOD)),
    british_isles = .data$country %in% BRITISH_ISLES,
    # The UK: Great Britain plus the six counties of Northern Ireland (Dove
    # files the whole island of Ireland as one country).
    uk = .data$country %in% c("England", "Wales", "Scotland") |
      (.data$country == "Island of Ireland" &
         .data$county %in% c("Antrim", "Armagh", "Down", "Fermanagh", "Derry",
                             "Londonderry", "Tyrone"))
  ) |>
  dplyr::filter(is.finite(.data$ld))

# ---- one-sided model: ring size against density, British Isles only --------
# The link between ring size and settlement is a British and Irish history.
bi  <- dplyr::filter(towers, .data$british_isles)
sfa <- fit_sfa(bi$ld, stats::model.matrix(~ ring_class - 1, bi))
names(sfa$a) <- RING_LABELS

frontier <- tibble::tibble(
  ring_class = factor(RING_LABELS, levels = RING_LABELS),
  frontier   = 10^sfa$a,
  lower      = 10^(sfa$a - 1.96 * sfa$a_se),
  upper      = 10^(sfa$a + 1.96 * sfa$a_se)
)

towers <- towers |>
  dplyr::mutate(
    resid = .data$ld - sfa$a[as.character(.data$ring_class)],
    u     = jlms_u(.data$resid, sfa$sv, sfa$su),
    type_a = classify_settlement_a(.data[[DRAFT_A_LOCAL_VAR]], .data$pop_r2km, .data$pop_r5km,
                                   .data[[REGION_VAR]], .data$society, DRAFT_A,
                                   TYPE_LEVELS_A),
    # An identifier for each urban centre (its population and area together),
    # and its average density (people per km2 of its 1 km cells).
    centre_key = ifelse(is.na(.data$centre_pop), NA_character_,
                        paste(round(.data$centre_pop), .data$centre_km2)),
    centre_density = .data$centre_pop / .data$centre_km2,
    type = classify_settlement_b(.data$centre_pop, .data$centre_density, .data[[LOCAL_VAR]],
                                 .data$other_bells_1km, .data$society, DRAFT_B, TYPE_LEVELS)
  )
bi <- dplyr::filter(towers, .data$british_isles)
frame_towers <- dplyr::filter(towers, .data$in_frame)
type_share <- prop.table(table(frame_towers$type))

# 1988 drew from towers with five or more bells, in the British Isles.
comparable_1988 <- dplyr::filter(frame_towers, .data$british_isles, .data$bells >= 5)

# How Draft B's types map onto 1988's five.
crosswalk_1988 <- c(
  "Small village or hamlet"    = "Village",
  "Village"                    = "Village",
  "Town"                       = "Town",
  "City or large town"         = "Large City",
  "Suburban"                   = "Suburban",
  "Inner city"                 = "Inner City",
  "Historic city core"         = "Large City"
)
