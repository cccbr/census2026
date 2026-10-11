# _common.R --------------------------------------------------------------------
#
# Shared set-up for the settlement chapters (tower-context, bells-remember,
# settlement-classes, sampling-design). Each chapter sources this after
# scripts/00_setup.R, so all chapters use the same data, the same
# provisional choices and the same classification.
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
#   LOCAL_VAR:   the walkable population: people per km2 of LAND in the
#                250 m kernel (half its weight within about 600 m). The town
#                and village lines (D-037). It also fits band outcomes best
#                in the Gloucester & Bristol register (chapter 2).
#   NRES_VAR:    the non-residential share of the built-up surface in the
#                500 m kernel: shops, offices and the like. Finds centres
#                where retail centres are not mapped (abroad), and is kept as
#                a descriptive measure (D-036).
#   TIGHT_VAR:   the 250 m kernel, as named in the side-quest chapter on what
#                the bells remember.
#   beyond_walk: an indicator, not a classifier (D-037): people per km2 of
#                land within reach by car but beyond walking distance, the
#                2 km kernel with the 250 m kernel's people and land taken
#                out. Sorts the draw within strata.
#   Densities, not counts, so the lines compare with the Degree of
#   Urbanisation's 300 and 1,500 per km2 (Mark, 2026-10-11).
#   REGION_VAR:  the wider region (8 km kernel).
DENSITY_VAR   <- "density_land_k2km"
LOCAL_VAR     <- "density_land_k250m"
NRES_VAR      <- "nres_share_k500m"
TIGHT_VAR     <- "density_land_k250m"
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

# Draft C thresholds: the working draft (D-037). See R/settlement.R.
#   conurbation_pop: an urban centre this size or larger is a conurbation.
#     Set in a gap in UK centre sizes (Nottingham 636k | Leicester 513k), so
#     small data changes cannot move a city across it; keeps Bristol in.
#   centre_retail_tier, centre_retail_m: inside an urban centre, a tower is
#     central if it is within 250 m (about three minutes' walk: on or by the
#     high street) of a retail centre of tier 4 or larger: a district centre,
#     town centre or market town, major town centre or regional centre
#     (scripts/12_build_retail_context.R). District centres count because the
#     classification ranks centres against bigger neighbours: Warwick and
#     Dudley are district centres.
#   centre_nres_ratio: where retail centres are not mapped (abroad), a tower
#     is central instead if the non-residential share of the buildings
#     around it is at least its urban centre's own share (D-036).
#   old_centre_towers: inside an urban centre, a tower with this many frame
#     towers within 1 km (itself included) is central whatever is round it.
#   cluster_towers: the tower-cluster flag. 5 or more frame towers within
#     1 km, itself included: towers close enough for one band to ring several
#     in a morning (Mark, 2026-10-11).
#   town_density: a town outside an urban centre, people per km2 of land in
#     the 250 m kernel. 600 is the best match to 1988's share of towns.
#   village_density: below this, a small village or hamlet. 200, below the
#     Degree of Urbanisation's cluster line (300), so that "village" is not
#     one monolithic class and the larger type keeps the plainer name (Mark).
DRAFT_C <- list(conurbation_pop = 575000, centre_retail_tier = 4, centre_retail_m = 250,
                centre_nres_ratio = 1, old_centre_towers = 3,
                cluster_towers = 5, town_density = 600, village_density = 200)

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
                 "City or large town: suburb", "City or large town: centre",
                 "Conurbation: suburb", "Conurbation: centre")
# Each settlement's suburb is a lighter shade of its centre's colour.
PAL_TYPE <- stats::setNames(c(PAL_CAT[c(3, 1, 4)], "#f5a37a", PAL_CAT[2],
                              "#a99be8", PAL_CAT[7]), TYPE_LEVELS)
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
retail    <- arrow::read_parquet(cur("tower_retail"))   # scripts/12 (D-037)
known     <- readr::read_csv(
  here::here("data", "reference", "known_towers.csv"),
  col_types = readr::cols(.default = "c")
)

# The new measures from script 08 (2026-10-10). Stop early, with a clear
# message, if the context table predates them.
needed_cols <- c("density_land_k250m", "density_land_k500m", "density_land_r500m",
                 "centre_pop", "urban_pop", "rural_cluster_pop", "centre_dist_km",
                 "nres_share_k500m", "centre_nres_share")
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
  dplyr::left_join(retail, by = "tower_id") |>
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
    isolation  = log10((.data[[TIGHT_VAR]] + 1) / (.data[[REGION_VAR]] + 1)),
    coast      = 1 - .data$land_share_k8km,
    society    = !is.na(.data$special) & .data$special %in% SOCIETY_CATEGORIES,
    # Bells within 1 km at OTHER frame towers. bells_r1km counts frame towers
    # only, so a frame tower's own bells are subtracted; others never counted.
    other_bells_1km = .data$bells_r1km - ifelse(.data$in_frame, .data$bells, 0),
    # People within reach by car but beyond walking distance (D-037).
    beyond_walk = (.data$pop_k2km - .data$pop_k250m) /
      (.data$land_km2_k2km - .data$land_km2_k250m),
    # Frame towers within 1 km, the tower itself included. towers_r1km counts
    # frame towers only, so a tower outside the frame adds itself.
    towers_1km = .data$towers_r1km + ifelse(.data$in_frame, 0, 1),
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
    centre_density = .data$centre_pop / .data$centre_km2
  )

# How Draft C's types map onto 1988's five. Tower clusters are mapped
# separately, to "Large City" (see type_1988).
crosswalk_1988 <- c(
  "Small village or hamlet"    = "Village",
  "Village"                    = "Village",
  "Town"                       = "Town",
  "City or large town: suburb" = "Suburban",
  "City or large town: centre" = "Large City",
  "Conurbation: suburb"        = "Suburban",
  "Conurbation: centre"        = "Inner City"
)

towers <- towers |>
  dplyr::mutate(
    # The non-residential share round the church against its whole urban
    # centre's: above 1, more commercial than its town as a whole.
    nres_ratio = .data[[NRES_VAR]] / .data$centre_nres_share,
    # On or by a high street (UK only; NA abroad, where retail centres are not
    # mapped and the non-residential share is used instead).
    retail_near = retail_near(dplyr::pick(dplyr::starts_with("retail_d_t")), DRAFT_C),
    type = classify_settlement_c(.data$centre_key, .data$centre_pop, .data[[LOCAL_VAR]],
                                 .data$retail_near, .data$nres_ratio, .data$towers_1km,
                                 .data$in_frame, DRAFT_C, TYPE_LEVELS),
    tower_cluster = tower_cluster(.data$towers_1km, .data$society, DRAFT_C),
    # 1988's five types. Tower clusters go to "Large City": 1988's type of the
    # great city-centre churches, with the most ringers per bell.
    type_1988 = ifelse(.data$tower_cluster, "Large City", unname(crosswalk_1988[as.character(.data$type)]))
  )
bi <- dplyr::filter(towers, .data$british_isles)
frame_towers <- dplyr::filter(towers, .data$in_frame)
type_share <- prop.table(table(frame_towers$type))

# 1988 drew from towers with five or more bells, in the British Isles.
comparable_1988 <- dplyr::filter(frame_towers, .data$british_isles, .data$bells >= 5)
