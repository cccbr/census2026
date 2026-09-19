# 01_fetch_dove.R -------------------------------------------------------------
#
# Fetch an immutable, checksummed snapshot of Dove's Guide.
#
# Run interactively. Safe to re-run: it refuses to overwrite an existing
# snapshot for today's date. To take a deliberate new snapshot on the same day,
# pass a different `snapshot_id`.
#
# Dove's Guide data is CC BY-SA 4.0. See DOVE_ATTRIBUTION in 00_setup.R and the
# Licensing section of README.md.

source(here::here("scripts", "00_setup.R"))

library(httr2)

# -----------------------------------------------------------------------------
# What we fetch and why
#
#   dove.csv     Full-circle rings. THIS IS THE SAMPLING FRAME SOURCE.
#   towers.csv   All bell collections including chimes and carillons. Fetched
#                for completeness and for reconciling frame exclusions; not the
#                frame itself.
#   regions.csv  Region hierarchy and abbreviations. Needed to resolve county /
#                region codes into the labels respondents will recognise.
#
# Dove warns that "the number and order of the fields may change from time to
# time, but we will endeavour to keep the column headings stable." Hence:
# reference columns by NAME, never by position, everywhere downstream.
# -----------------------------------------------------------------------------

DOVE_FILES <- c(
  dove    = "https://dove.cccbr.org.uk/dove.csv",
  towers  = "https://dove.cccbr.org.uk/towers.csv",
  regions = "https://dove.cccbr.org.uk/regions.csv"
)

snapshot_date <- Sys.Date()
snapshot_id   <- paste0("dove_", format(snapshot_date, "%Y-%m-%d"))
dest          <- snapshot_dir("dove", snapshot_date)

if (fs::dir_exists(dest) && length(fs::dir_ls(dest)) > 0) {
  stop(
    "A snapshot already exists at:\n  ", dest, "\n",
    "Raw snapshots are immutable. Delete it deliberately, or change ",
    "snapshot_date, if you really mean to refetch.",
    call. = FALSE
  )
}
fs::dir_create(dest)

# ---- fetch ------------------------------------------------------------------

fetch_one <- function(name, url) {
  message("Fetching ", name, " from ", url)

  resp <- request(url) |>
    req_user_agent("CCCBR Ringing Census 2026 (https://github.com/cccbr/ringing-census-2026)") |>
    req_retry(max_tries = 3) |>
    req_perform()

  out <- fs::path(dest, paste0(name, ".csv"))
  writeBin(resp_body_raw(resp), out)

  # Row count from the file itself, not from a parse — a parse that silently
  # drops malformed rows would make the provenance record a lie.
  n_rows <- length(readLines(out, warn = FALSE)) - 1L

  tibble::tibble(
    snapshot_id   = snapshot_id,
    source        = "dove",
    file          = paste0(name, ".csv"),
    url           = url,
    fetched_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    http_status   = resp_status(resp),
    etag          = resp_header(resp, "etag")          %||% NA_character_,
    last_modified = resp_header(resp, "last-modified") %||% NA_character_,
    bytes         = fs::file_size(out) |> as.numeric(),
    n_rows        = n_rows,
    sha256        = file_sha256(out),
    fetched_by    = Sys.info()[["user"]]
  )
}

manifest <- DOVE_FILES |>
  purrr::imap(\(url, name) fetch_one(name, url)) |>
  purrr::list_rbind()

# ---- record -----------------------------------------------------------------

# Sidecar next to the bytes ...
jsonlite::write_json(
  manifest, fs::path(dest, "_manifest.json"),
  auto_unbox = TRUE, pretty = TRUE
)

# ... and a row in the committed, append-only register.
purrr::pwalk(manifest, \(...) append_fetch_log(tibble::tibble(...)))

print(manifest |> dplyr::select(file, n_rows, bytes, sha256))

message(
  "\nSnapshot ", snapshot_id, " written to:\n  ", dest,
  "\n\nNEXT: commit provenance/fetch_log.csv, then run scripts/02_profile_dove.R"
)

# -----------------------------------------------------------------------------
# A note on re-running
#
# Taking a new snapshot does not invalidate the old one. Both stay on disk and
# both stay in the log. The frame build (04) names the snapshot it uses
# explicitly; it never silently picks "the latest". Once the questionnaire ships,
# the frame snapshot is frozen and any later snapshot is for reconciliation
# only — for answering "what changed between September and November?", which is
# a real analytical question, not a reason to move the denominator.
# -----------------------------------------------------------------------------
