# B05_build_tower_classes.R ----------------------------------------------------
#
# Classify every tower by settlement type and save the result, so that the
# analysis chapters, the volunteers' map and the chased-sample draw all read
# one stated classification, with a record of which snapshot and which choices
# produced it.
#
# The rule is Draft C (D-037), applied by classify_towers() in R/towers.R with
# the thresholds in config/choices.R. Re-run after changing either, or after
# re-running B03 or B04.
#
# Output: data/curated/tower_classes_<FRAME_SNAPSHOT>.parquet (+ .json
# sidecar), one row per tower:
#   - every tower with a ringable full-circle ring of 3+ bells (ringable = TRUE;
#     in_frame marks the sampling frame), and
#   - towers with only unringable rings (ringable = FALSE), classified by the
#     same rule but never a settlement's fallback centre, for the map.
# The sidecar records the thresholds used.

source(here::here("scripts", "00_setup.R"))

cur <- \(stem) here::here("data", "curated", paste0(stem, "_", FRAME_SNAPSHOT, ".parquet"))
frame     <- arrow::read_parquet(cur("frame"))
locations <- arrow::read_parquet(cur("tower_locations"))
context   <- arrow::read_parquet(cur("tower_context"))
retail    <- arrow::read_parquet(cur("tower_retail"))
special   <- readr::read_csv(here::here("data", "reference", "special_towers_draft.csv"),
                             col_types = readr::cols(.default = "c"))

ringable <- assemble_towers(frame, locations, context, retail, special,
                            MULTI_RING_BELLS, SOCIETY_CATEGORIES,
                            DENSITY_VAR, TIGHT_VAR, REGION_VAR) |>
  classify_towers(LOCAL_VAR, NRES_VAR, DRAFT_C, TYPE_LEVELS, crosswalk_1988)

unringable <- assemble_unringable(frame, locations, context, retail, special,
                                  SOCIETY_CATEGORIES, exclude_ids = ringable$tower_id) |>
  classify_towers(LOCAL_VAR, NRES_VAR, DRAFT_C, TYPE_LEVELS, crosswalk_1988,
                  eligible = FALSE)

classes <- dplyr::bind_rows(
  ringable   |> dplyr::mutate(ringable = TRUE),
  unringable |> dplyr::mutate(ringable = FALSE)
) |>
  dplyr::transmute(
    tower_id, ringable, in_frame, display, bells, country, county,
    uk,
    # The result. Type is stored as text so it reads the same in Python;
    # TYPE_LEVELS in config/choices.R gives the order.
    type = as.character(.data$type), type_1988, tower_cluster,
    # What the rule looked at, so any tower's type can be checked by hand.
    centre_pop, centre_key, local_density = .data[[LOCAL_VAR]],
    retail_near, nres_ratio, towers_1km, society, special
  )

stopifnot("every tower needs a type" = !anyNA(classes$type),
          "one row per tower" = !anyDuplicated(classes$tower_id))

out <- cur("tower_classes")
write_artefact(classes, path = out, snapshot_id = FRAME_SNAPSHOT,
               script = "scripts/B05_build_tower_classes.R")

# Record the choices beside the lineage, so the file says which rule made it.
side <- fs::path_ext_set(out, "json")
meta <- jsonlite::read_json(side)
meta$choices <- list(rule = "Draft C (D-037)", thresholds = DRAFT_C,
                     local_var = LOCAL_VAR, nres_var = NRES_VAR,
                     density_var = DENSITY_VAR, multi_ring_bells = MULTI_RING_BELLS,
                     society_categories = SOCIETY_CATEGORIES)
jsonlite::write_json(meta, side, auto_unbox = TRUE, pretty = TRUE)

frame_share <- classes |> dplyr::filter(.data$in_frame) |> dplyr::count(.data$type) |>
  dplyr::mutate(share = scales::percent(.data$n / sum(.data$n), accuracy = 0.1))
message("Wrote ", out, ": ", nrow(classes), " towers (", sum(classes$in_frame),
        " in the frame).")
print(frame_share)
