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

# Snapshots and the provisional choices (thresholds, measures, type names)
# live in config/, sourced by scripts/00_setup.R.

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
# Each settlement's suburb is a lighter shade of its centre's colour.
# Greens for the countryside (pale for the smallest places), amber for towns,
# reds for cities (light for suburbs), purples for conurbations (Mark).
PAL_TYPE <- stats::setNames(c("#8fcb8a", "#3f9a33", PAL_CAT[4], "#e0938b", "#c0392b",
                              "#a99be8", PAL_CAT[7]), TYPE_LEVELS)

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
retail    <- arrow::read_parquet(cur("tower_retail"))   # scripts/B04 (D-037)
known     <- readr::read_csv(
  here::here("data", "reference", "known_towers.csv"),
  col_types = readr::cols(.default = "c")
)

# The new measures from script B03 (2026-10-10). Stop early, with a clear
# message, if the context table predates them.
needed_cols <- c("density_land_k250m", "density_land_k500m", "density_land_r500m",
                 "centre_pop", "urban_pop", "rural_cluster_pop", "centre_dist_km",
                 "nres_share_k500m", "centre_nres_share")
missing_cols <- setdiff(needed_cols, names(context))
if (length(missing_cols) > 0) {
  stop("The tower context table is missing ", paste(missing_cols, collapse = ", "),
       ". Re-run scripts/B03_build_tower_context.R.", call. = FALSE)
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
