# 05_export_questionnaire_towers.R --------------------------------------------
#
# Generate the tower list served to the questionnaire.
#
# Output: inst/questionnaire/build/towers_<snapshot_id>.txt
#
#   # <snapshot_id> <n_rings> <n_chars>
#   <RingID>|<display>|<alt names>
#   ...
#
# The file is uploaded to a web host and fetched by the widget at runtime
# (D-015). It is NOT embedded in the questionnaire: QuestionPro caps its
# JavaScript Logic field at 16,000-32,000 characters and its content blocks at
# 10,000, and no encoding closes a gap that size for 6,161 place names.
#
# It is plain text and not JavaScript (D-016). A .js file loaded by a script
# tag would execute remote code in the respondent's browser, so a compromised
# host could run anything on a page collecting census responses. Fetched as
# data, the worst case is bad data - which the header counts catch.
#
# The build directory is gitignored: this is a generated artefact, rebuilt
# from the curated frame whenever the snapshot changes.

source(here::here("scripts", "00_setup.R"))

SNAPSHOT_ID <- "dove_2026-09-19"          # must match scripts/04_build_frame.R

# ---- load the curated frame -------------------------------------------------

frame_path <- fs::path(here::here("data", "curated"),
                       paste0("frame_", SNAPSHOT_ID, ".parquet"))
stopifnot(fs::file_exists(frame_path))

pick <- arrow::read_parquet(frame_path) |>
  dplyr::filter(.data$frame_picklist) |>
  dplyr::arrange(.data$display)

message("Picklist rows: ", format(nrow(pick), big.mark = ","))

# ---- checks before anything is written --------------------------------------

# A duplicate display string is unusable in a picklist: the respondent cannot
# tell which entry is theirs, and whichever they pick is a coin flip.
dups <- find_duplicate_displays(pick, display_col = "display", id_col = "ring_id")
if (nrow(dups) > 0) {
  print(dups |> dplyr::select(ring_id, display))
  stop("Colliding display strings. Fix build_display() before exporting.", call. = FALSE)
}

# The format is pipe-delimited, newline-separated, so neither character may
# appear in a field. Strip rather than escape - no tower name legitimately
# contains a pipe, and escaping would complicate the parser for nothing.
clean <- function(x) {
  x |>
    tidyr::replace_na("") |>
    stringr::str_replace_all("[|\r\n]", " ") |>
    stringr::str_squish()
}

lines <- paste0(pick$ring_id, "|", clean(pick$display), "|", clean(pick$alt_terms))
payload <- paste0(paste(lines, collapse = "\n"), "\n")

# ---- write ------------------------------------------------------------------
#
# Integrity is carried as row count and character count, not a checksum. Those
# catch the realistic failures - truncation and a partial browser-cache write.
# Corruption in transit is prevented by HTTPS, the wrong file is caught by the
# snapshot id, and a hash cannot detect tampering because whoever can alter the
# file can alter the header. A 32-bit hash would also have to be reimplemented
# identically in JavaScript, and R has no native unsigned 32-bit arithmetic -
# precisely the cross-language divergence risk already being managed with the
# search-key normaliser.

n_chars <- nchar(payload, type = "chars")
header  <- sprintf("# %s %d %d\n", SNAPSHOT_ID, nrow(pick), n_chars)

out_dir <- here::here("inst", "questionnaire", "build")
fs::dir_create(out_dir)
out <- fs::path(out_dir, paste0("towers_", SNAPSHOT_ID, ".txt"))

readr::write_file(paste0(header, payload), out)

message(sprintf(
  "\nWrote %s\n  %d rings, %s characters, %.0f KB on disk (~80 KB gzipped in transit)",
  out, nrow(pick), format(n_chars, big.mark = ","),
  as.numeric(fs::file_size(out)) / 1024
))

# A record of what was generated, so a deployed questionnaire can be traced
# back to a snapshot without keeping the artefact in git.
jsonlite::write_json(
  list(
    generated_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    script           = "scripts/05_export_questionnaire_towers.R",
    snapshot_id      = SNAPSHOT_ID,
    frame_artefact   = fs::path_file(frame_path),
    n_rings          = nrow(pick),
    n_chars          = n_chars,
    bytes            = as.numeric(fs::file_size(out)),
    sha256           = file_sha256(out)
  ),
  fs::path(out_dir, paste0("towers_", SNAPSHOT_ID, ".json")),
  auto_unbox = TRUE, pretty = TRUE
)

message("\nNext:")
message("  1. Upload this file to the agreed host.")
message("  2. Set CFG.dataUrl in inst/questionnaire/tower_autocomplete_v4.js to its URL.")
message("  3. Paste that whole file into QuestionPro's Pre JavaScript Logic.")
message("  4. Set CFG.debug = false before fieldwork.")
