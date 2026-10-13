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
PAL_TYPE <- stats::setNames(TYPE_COLOURS, TYPE_LEVELS)   # config/choices.R

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
# assemble_towers() is in R/towers.R, shared with scripts/B05.
towers <- assemble_towers(frame, locations, context, retail, special,
                          MULTI_RING_BELLS, SOCIETY_CATEGORIES,
                          DENSITY_VAR, TIGHT_VAR, REGION_VAR) |>
  dplyr::mutate(ring_class = cut(.data$bells, RING_BREAKS, RING_LABELS),
                smod_class = factor(.data$smod_class, levels = names(PAL_SMOD)))

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
                                   TYPE_LEVELS_A)
  ) |>
  # Draft C, by the same function scripts/B05 uses to save the classification.
  classify_towers(LOCAL_VAR, NRES_VAR, DRAFT_C, TYPE_LEVELS, crosswalk_1988)

# The saved classification is what the map and the sample draw read. If the
# chapters now classify differently (choices changed, B05 not re-run), say so.
classes_file <- cur("tower_classes")
if (fs::file_exists(classes_file)) {
  saved <- arrow::read_parquet(classes_file) |> dplyr::select("tower_id", saved_type = "type")
  n_diff <- towers |> dplyr::inner_join(saved, by = "tower_id") |>
    dplyr::filter(as.character(.data$type) != .data$saved_type) |> nrow()
  if (n_diff > 0) {
    message(n_diff, " towers differ from the saved classification in ", classes_file,
            ". Re-run scripts/B05_build_tower_classes.R before publishing the map ",
            "or drawing the sample.")
  }
} else {
  message("No saved classification yet: run scripts/B05_build_tower_classes.R.")
}

bi <- dplyr::filter(towers, .data$british_isles)
frame_towers <- dplyr::filter(towers, .data$in_frame)
type_share <- prop.table(table(frame_towers$type))

# 1988 drew from towers with five or more bells, in the British Isles.
comparable_1988 <- dplyr::filter(frame_towers, .data$british_isles, .data$bells >= 5)
