# config/snapshots.R ----------------------------------------------------------
#
# Every data snapshot the project reads, named once. Sourced by
# scripts/00_setup.R, so every script, chapter and publishing script uses the
# same ones.
#
# Snapshots are NAMED, never discovered. Nothing picks "the latest": Dove and
# the geography sources change continuously, and if the frame drifted between
# building the questionnaire list and analysing the replies, replies could not
# be matched to frame rows and the denominator would move.
#
# Changing a line here changes what the whole project reads. Do it
# deliberately, in its own commit, and re-run the pipeline from the stage the
# snapshot belongs to. Fetch scripts (A01, B02) create new snapshots; they do
# not read these names.

# Stage A: Dove's Guide, and the frame built from it ---------------------------
FRAME_SNAPSHOT <- "dove_2026-09-19"

# Stage B: geography (fetched by scripts/B02_fetch_geography.R) ---------------
GHSL_POP_SNAPSHOT   <- "ghsl_pop_E2020_2026-10-10"
GHSL_SMOD_SNAPSHOT  <- "ghsl_smod_E2020_2026-10-10"
ONS_RUC_SNAPSHOT    <- "ons_oa_ruc_2026-10-10"
GHSL_LAND_SNAPSHOT  <- "ghsl_land_E2018_2026-10-10"
GHSL_BUILT_SNAPSHOT <- "ghsl_built_E2020_2026-10-11"
GHSL_NRES_SNAPSHOT  <- "ghsl_nres_E2020_2026-10-11"

# Stage B: retail centres (downloaded by hand after registration; see
# scripts/B04_build_retail_context.R) -------------------------------------------
CDRC_SNAPSHOT <- "cdrc_retail_2026-10-11"
