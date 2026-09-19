# io.R ------------------------------------------------------------------------
#
# Snapshot and provenance helpers.
#
# CONTRACT FOR EVERYTHING IN R/:
#   Functions take explicit inputs and return values. They do not run on
#   source(). They do not decide where the project lives beyond here::here().
#   All side effects belong in scripts/.
#
# WHY SNAPSHOTS
#   Dove's Guide changes continuously — augmentations, new rings, towers going
#   unringable. The census sampling frame must be a *stated* snapshot, frozen on
#   a stated date, or the denominator moves between building the questionnaire
#   and running the analysis and responses can no longer be matched to frame
#   rows. Every raw fetch therefore lands in an immutable, dated, checksummed
#   directory and is never overwritten.
#
# WHERE THE AUDIT TRAIL LIVES
#   The bytes live in data/raw/ (untracked). The *claim* about those bytes —
#   URL, timestamp, SHA-256, row count — lives in provenance/fetch_log.csv,
#   which IS committed. Anyone can verify a snapshot from the repo alone,
#   without the repo ever containing the data.

# ---- paths ------------------------------------------------------------------

#' Directory for one dated snapshot of one source
#'
#' @param source Short source name, e.g. "dove".
#' @param date   Snapshot date (Date).
#' @return fs_path
snapshot_dir <- function(source, date = Sys.Date()) {
  fs::path(here::here("data", "raw"), source, format(as.Date(date), "%Y-%m-%d"))
}

#' The most recent snapshot directory for a source
#'
#' @return fs_path, or NA if none exists.
latest_snapshot_dir <- function(source) {
  root <- fs::path(here::here("data", "raw"), source)
  if (!fs::dir_exists(root)) {
    return(NA)
  }
  dirs <- fs::dir_ls(root, type = "directory")
  dirs <- dirs[grepl("\\d{4}-\\d{2}-\\d{2}$", dirs)]
  if (length(dirs) == 0) NA else sort(dirs, decreasing = TRUE)[[1]]
}

# ---- checksums --------------------------------------------------------------

#' SHA-256 of a file on disk
file_sha256 <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

#' Verify a file against a recorded checksum
#'
#' @return TRUE invisibly, or throws with a diagnostic.
verify_sha256 <- function(path, expected) {
  actual <- file_sha256(path)
  if (!identical(actual, expected)) {
    stop(
      "Checksum mismatch for ", path, "\n",
      "  expected: ", expected, "\n",
      "  actual:   ", actual, "\n",
      "This file is not the one recorded in provenance/fetch_log.csv.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# ---- the fetch log ----------------------------------------------------------

FETCH_LOG <- function() here::here("provenance", "fetch_log.csv")

FETCH_LOG_COLS <- c(
  "snapshot_id", "source", "file", "url", "fetched_at_utc",
  "http_status", "etag", "last_modified", "bytes", "n_rows", "sha256", "fetched_by"
)

#' Append one row to the committed fetch log
#'
#' Append-only by design: rows are never edited or removed. A superseded
#' snapshot stays in the log, which is the point.
append_fetch_log <- function(row) {
  stopifnot(all(FETCH_LOG_COLS %in% names(row)))
  row <- row[FETCH_LOG_COLS]
  path <- FETCH_LOG()
  fs::dir_create(fs::path_dir(path))

  if (fs::file_exists(path)) {
    readr::write_csv(row, path, append = TRUE)
  } else {
    readr::write_csv(row, path)
  }
  invisible(row)
}

#' Read the fetch log
read_fetch_log <- function() {
  path <- FETCH_LOG()
  if (!fs::file_exists(path)) {
    return(tibble::tibble())
  }
  readr::read_csv(path, show_col_types = FALSE)
}

# ---- derived artefacts ------------------------------------------------------

#' Write a derived artefact alongside a sidecar recording its lineage
#'
#' Every curated table records which raw snapshot it came from and which script
#' built it. If you cannot answer "which snapshot is this number from?" the
#' number is not defensible.
#'
#' @param x           Data frame to write.
#' @param path        Destination (.parquet).
#' @param snapshot_id Snapshot id(s) this artefact derives from.
#' @param script      Script that produced it, e.g. "scripts/04_build_frame.R".
write_artefact <- function(x, path, snapshot_id, script) {
  fs::dir_create(fs::path_dir(path))
  arrow::write_parquet(x, path)

  sidecar <- list(
    artefact     = fs::path_file(path),
    built_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    built_by     = Sys.info()[["user"]],
    script       = script,
    snapshot_id  = snapshot_id,
    n_rows       = nrow(x),
    n_cols       = ncol(x),
    columns      = names(x),
    sha256       = file_sha256(path)
  )
  jsonlite::write_json(
    sidecar,
    fs::path_ext_set(path, "json"),
    auto_unbox = TRUE, pretty = TRUE
  )
  invisible(path)
}
