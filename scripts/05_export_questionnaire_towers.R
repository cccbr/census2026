# 05_export_questionnaire_towers.R --------------------------------------------
#
# Generate the deployable QuestionPro autocomplete script: the v3 template with
# the tower payload substituted in.
#
# This replaces the earlier `dove_to_qp_js.py`, which lived outside the
# repository. The point of moving it here is that the picklist and the analysis
# frame now come from the same frozen snapshot, with the same provenance
# record. Otherwise the two can drift and nothing detects it.
#
# Output: inst/questionnaire/build/tower_autocomplete_<snapshot_id>.js
#         (gitignored — it is a build artefact, regenerated from the template
#          and the frame, and it is 300KB of generated data)

source(here::here("scripts", "00_setup.R"))

SNAPSHOT_ID <- "dove_2026-09-19"          # must match scripts/04_build_frame.R

# ---- load the curated frame -------------------------------------------------

frame_path <- fs::path(here::here("data", "curated"),
                       paste0("frame_", SNAPSHOT_ID, ".parquet"))
stopifnot(fs::file_exists(frame_path))

frame <- arrow::read_parquet(frame_path)

pick <- frame |>
  dplyr::filter(.data$frame_picklist) |>
  dplyr::arrange(.data$display)

message("Picklist rows: ", format(nrow(pick), big.mark = ","))

# ---- sanity checks before anything is generated -----------------------------
#
# A duplicate display string is unusable in a picklist — the respondent cannot
# tell which entry is theirs, and whichever they pick is a coin flip. Two are
# expected (Farnham S Andrew: a ring of ten and a 30lb mini ten).

dups <- find_duplicate_displays(pick, display_col = "display", id_col = "ring_id")
if (nrow(dups) > 2) {
  print(dups |> dplyr::select(ring_id, display))
  stop("More colliding display strings than expected. Fix build_display() before exporting.",
       call. = FALSE)
}

# The payload is pipe-delimited and newline-separated, so neither character may
# appear in a field. Strip rather than escape: simpler, and no tower name
# legitimately contains a pipe.
clean <- function(x) {
  x |>
    tidyr::replace_na("") |>
    stringr::str_replace_all("[|\r\n]", " ") |>
    stringr::str_squish()
}

payload <- paste0(
  pick$ring_id, "|", clean(pick$display), "|", clean(pick$alt_terms),
  collapse = "\n"
)

# ---- substitute into the template -------------------------------------------

template_path <- here::here("inst", "questionnaire", "tower_autocomplete_v3.js")
template <- readr::read_file(template_path)

# The placeholder must appear EXACTLY ONCE.
#
# `sub()` replaces the first occurrence. An early draft of the template also
# named the token in its header comment, so the entire 304KB payload was
# substituted into a `//` line and the real `var DATA = ` assignment was left
# as a literal syntax error. The file was the right size and completely
# non-functional — which is the worst kind of wrong, because the size test
# still passed.
hits <- gregexpr("__TOWER_DATA__", template, fixed = TRUE)[[1]]
n_marks <- if (hits[1] == -1L) 0L else length(hits)
if (n_marks != 1L) {
  stop("Template must contain exactly one data placeholder; found ", n_marks,
       ". Check for a second occurrence in a comment.", call. = FALSE)
}

# toJSON with auto_unbox gives a correctly escaped JavaScript string literal,
# quotes included. Do not hand-roll this: a stray backslash or quote in a
# dedication would produce a script that fails to parse, and QuestionPro gives
# no useful error when that happens.
payload_literal <- as.character(jsonlite::toJSON(payload, auto_unbox = TRUE))

script <- sub("__TOWER_DATA__", payload_literal, template, fixed = TRUE)

# Verify the substitution landed where it was meant to. Cheap, and it is the
# difference between shipping a working script and shipping a syntax error of
# exactly the right file size.
stopifnot(!grepl("__TOWER_DATA__", script, fixed = TRUE))
stopifnot(grepl('var DATA = "', script, fixed = TRUE))

# ---- write ------------------------------------------------------------------

out_dir <- here::here("inst", "questionnaire", "build")
fs::dir_create(out_dir)
out <- fs::path(out_dir, paste0("tower_autocomplete_", SNAPSHOT_ID, ".js"))

readr::write_file(script, out)

size_kb <- as.numeric(fs::file_size(out)) / 1024
message(sprintf("\nWrote %s\n  %.0f KB total, %.0f KB of which is payload",
                out, size_kb, nchar(payload_literal, type = "bytes") / 1024))

# A record of what was generated, so a deployed script can be traced back to a
# snapshot without keeping the 300KB artefact in git.
jsonlite::write_json(
  list(
    generated_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    script           = "scripts/05_export_questionnaire_towers.R",
    snapshot_id      = SNAPSHOT_ID,
    template         = "inst/questionnaire/tower_autocomplete_v3.js",
    frame_artefact   = fs::path_file(frame_path),
    n_rings          = nrow(pick),
    bytes            = as.numeric(fs::file_size(out)),
    sha256           = file_sha256(out)
  ),
  fs::path(out_dir, paste0("tower_autocomplete_", SNAPSHOT_ID, ".json")),
  auto_unbox = TRUE, pretty = TRUE
)

message("\nPaste the contents of that file into QuestionPro's Pre JavaScript Logic.")
message("Set CONFIG.debug = false before fieldwork.")
