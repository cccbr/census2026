# C01_import_gb_register.R -----------------------------------------------------
#
# Import the Gloucester & Bristol Diocesan Association's tower register: for
# each tower in the Association, its branch, its bells and the number of
# ringers on the register. Sent by Richard Heys, the Association's treasurer,
# on 11 October 2026. See data/reference/gb_register.md for what it is, how it
# was compiled, and what it can and cannot be used for.
#
# The register holds counts of ringers per named tower. That is the
# Association's data, shared with the project, and it is NOT published:
#
#   data/raw/gb_register/<date>/   the spreadsheet exactly as received
#                                  (gitignored, checksummed in the fetch log)
#   data/curated/gb_register_<snapshot>.parquet
#                                  tidy table with ringer counts (gitignored)
#   data/reference/gb_register_crosswalk.csv
#                                  register names matched to Dove towers.
#                                  Tower names and Dove ids only, no counts,
#                                  so it is committed and reviewable.
#
# The crosswalk follows the reference-data rule (data/reference/README.md):
# matching PROPOSES, a person DISPOSES. On first run this script writes
# proposals with reviewed = blank. Review each row, set reviewed to the
# reviewer's initials, correct tower_id where needed, and commit. Later runs
# read the reviewed file and never overwrite it.
#
# Run interactively after copying a newly received register into
# data/raw/gb_register/<date>/ and setting RECEIVED below.

source(here::here("scripts", "00_setup.R"))

FRAME_SNAPSHOT <- "dove_2026-09-19"

# ---- the file as received ----------------------------------------------------
RECEIVED <- list(
  snapshot_id = "gb_register_2025_2026-10-11",
  source      = "gb_register",
  date        = "2026-10-11",
  file        = "G&B Towers 2025.xlsx",
  from        = "Email from Richard Heys, Treasurer, Gloucester & Bristol Diocesan Association"
)

raw_path <- fs::path(snapshot_dir(RECEIVED$source, RECEIVED$date), RECEIVED$file)
stopifnot("register not found in data/raw/gb_register/<date>/" = fs::file_exists(raw_path))

# Record the file in the fetch log once, so its bytes are checksummed like
# every downloaded source; afterwards, verify it has not changed.
log <- read_fetch_log()
if (!RECEIVED$snapshot_id %in% log$snapshot_id) {
  append_fetch_log(tibble::tibble(
    snapshot_id    = RECEIVED$snapshot_id,
    source         = RECEIVED$source,
    file           = RECEIVED$file,
    url            = RECEIVED$from,
    fetched_at_utc = paste0(RECEIVED$date, "T00:00:00Z"),
    http_status    = NA_integer_,
    etag           = NA_character_,
    last_modified  = NA_character_,
    bytes          = as.numeric(fs::file_size(raw_path)),
    n_rows         = NA_integer_,
    sha256         = file_sha256(raw_path),
    fetched_by     = Sys.info()[["user"]]
  ))
  message("Recorded ", RECEIVED$file, " in the fetch log. Commit provenance/fetch_log.csv.")
} else {
  verify_sha256(raw_path, log$sha256[log$snapshot_id == RECEIVED$snapshot_id][[1]])
}

# ---- parse the "Source Data" sheet -------------------------------------------
#
# Layout, as received: one block of columns per branch, side by side. A
# header row holds each branch's name above "Bells" and "Ringers"; towers
# follow below it. A fourth column in a block, where filled, names a tower
# that shares the band ("& Dumbleton"). A row above the header holds each
# branch's own count of towers, used as a check. The other sheets ("Single
# List", "Exc Zero") are derived from this one by formulas and are not read.
#
# Rows are found by content, not position: readxl drops the sheet's empty
# first row and column, so positions differ from Excel's.
sheet <- readxl::read_excel(raw_path, sheet = "Source Data", col_names = FALSE,
                            .name_repair = "minimal", col_types = "text")
cell <- \(r, c) sheet[[c]][[r]]
header_row <- which(apply(sheet, 1, \(r) any(r %in% "Bells")))[[1]]
count_row  <- max(which(apply(sheet[seq_len(header_row - 1), , drop = FALSE], 1,
                              \(r) any(!is.na(r)))))
first_row  <- header_row + 1
starts <- which(vapply(seq_along(sheet), \(c) {
  v <- cell(header_row, c)
  !is.na(v) && is.character(v) && !v %in% c("Bells", "Ringers")
}, logical(1)))

register <- purrr::map(starts, \(c) {
  rows <- first_row:nrow(sheet)
  place <- sheet[[c]][rows]
  keep  <- !is.na(place) & nzchar(trimws(place))
  joint <- if (c + 3 <= ncol(sheet)) sheet[[c + 3]][rows][keep] else rep(NA_character_, sum(keep))
  joint <- trimws(sub("^&\\s*", "", joint))
  tibble::tibble(
    branch     = cell(header_row, c),
    place      = trimws(place[keep]),
    bells      = as.integer(sheet[[c + 1]][rows][keep]),
    ringers    = as.integer(sheet[[c + 2]][rows][keep]),
    joint_with = ifelse(is.na(joint) | !nzchar(joint), NA_character_, joint)
  )
}) |>
  purrr::list_rbind() |>
  # Some branches list "Unattached" ringers, registered with the branch but no
  # tower. They are kept, flagged, and never matched to a tower.
  dplyr::mutate(unattached = tolower(.data$place) == "unattached")

# The branch counts on row 2 are formulas; readxl reads their cached values.
expected <- vapply(starts, \(c) as.numeric(cell(count_row, c + 2)), 0)
got <- as.numeric(table(factor(register$branch, levels = vapply(starts, \(c) cell(header_row, c), ""))))
if (!all(is.na(expected)) && !isTRUE(all.equal(got[!is.na(expected)], expected[!is.na(expected)]))) {
  stop("Towers per branch do not match the sheet's own counts:\n",
       paste(sprintf("  %s: read %d, sheet says %s", unique(register$branch), got, expected),
             collapse = "\n"), call. = FALSE)
}
stopifnot("a tower without a bell count" = !anyNA(register$bells[!register$unattached]),
          "a row without a ringer count" = !anyNA(register$ringers))
message(sum(!register$unattached), " towers in ", length(starts), " branches; ",
        sum(register$ringers == 0 & !register$unattached), " with no ringers on the register; ",
        sum(register$ringers[register$unattached]), " unattached ringers")

# ---- match register names to Dove --------------------------------------------
#
# Candidates are Dove rings affiliated to the Association, ringable or not.
# Names are normalised ("St" and "Saint" to "S", punctuation dropped), and a
# branch hint in brackets, such as "(Chelt)", is set aside. A register name is
# matched, in order, to:
#   place            a unique Dove place of that name;
#   place_bells      one of several rings at that place, picked by bells;
#   place_dedication Dove place plus dedication, e.g. "Bristol St James";
# and is otherwise left for review.
frame <- arrow::read_parquet(here::here("data", "curated",
                                        paste0("frame_", FRAME_SNAPSHOT, ".parquet")))
norm <- function(x) {
  x |>
    tolower() |>
    gsub(pattern = "\\([^)]*\\)", replacement = " ") |>
    gsub(pattern = "\\bsaint\\b|\\bst\\b\\.?", replacement = "s") |>
    gsub(pattern = "[^a-z0-9 ]", replacement = " ") |>
    gsub(pattern = "\\s+", replacement = " ") |>
    trimws()
}
dove <- frame |>
  dplyr::filter(grepl("Gloucester and Bristol", .data$affiliations)) |>
  dplyr::transmute(.data$tower_id, .data$ring_id, .data$display, .data$bells,
                   p  = norm(.data$place),
                   pd = norm(paste(.data$place, .data$dedication)))

match_one <- function(name, bells, unattached) {
  n <- norm(name)
  # For a name left unmatched, list the Dove rings at a place named within it
  # with the same bells, to make review quick.
  suggest <- dplyr::filter(dove, vapply(.data$p, \(p) grepl(paste0("\\b", p, "\\b"), n), TRUE) |
                             vapply(.data$p, \(p) grepl(paste0("\\b", n, "\\b"), p), TRUE),
                           .data$bells == !!bells | is.na(!!bells))
  none <- tibble::tibble(tower_id = NA_character_, ring_id = NA_character_, display = NA_character_,
                         bells = NA_integer_, match_method = "unmatched",
                         candidates = paste(utils::head(suggest$display, 4), collapse = " | "))
  if (unattached) return(dplyr::mutate(none, match_method = "unattached", candidates = ""))
  hit <- dplyr::filter(dove, .data$p == n)
  if (nrow(hit) > 1) {
    by_bells <- dplyr::filter(hit, .data$bells == !!bells)
    if (nrow(by_bells) == 1) return(dplyr::mutate(by_bells, match_method = "place_bells", candidates = ""))
  }
  if (nrow(hit) == 1) return(dplyr::mutate(hit, match_method = "place", candidates = ""))
  hit <- dplyr::filter(dove, startsWith(.data$pd, n) | startsWith(n, .data$pd))
  if (nrow(hit) > 1) hit <- dplyr::filter(hit, .data$bells == !!bells)
  if (nrow(hit) == 1) return(dplyr::mutate(hit, match_method = "place_dedication", candidates = ""))
  none
}

crosswalk_path <- here::here("data", "reference", "gb_register_crosswalk.csv")
if (!fs::file_exists(crosswalk_path)) {
  proposals <- purrr::pmap(list(register$place, register$bells, register$unattached), match_one) |>
    purrr::list_rbind() |>
    dplyr::select("tower_id", "ring_id", dove_label = "display", dove_bells = "bells",
                  "match_method", "candidates")
  crosswalk <- dplyr::bind_cols(
    register |> dplyr::select("branch", register_place = "place", register_bells = "bells"),
    proposals
  ) |>
    # The register counts every bell; Dove counts the ring, so a twelve with a
    # flat shows as 13 in the register and 12 in Dove.
    dplyr::mutate(bells_differ = !is.na(.data$dove_bells) & .data$dove_bells != .data$register_bells,
                  reviewed = NA_character_, notes = NA_character_)
  readr::write_csv(crosswalk, crosswalk_path, na = "")
  message("Wrote PROPOSED matches to ", crosswalk_path, ": ",
          paste(names(table(crosswalk$match_method)), table(crosswalk$match_method),
                sep = " ", collapse = ", "),
          ". Review every row, then commit.")
} else {
  crosswalk <- readr::read_csv(crosswalk_path, col_types = readr::cols(.default = "c"))
  message("Using the reviewed crosswalk; ", sum(is.na(crosswalk$reviewed)),
          " rows still unreviewed.")
}

# ---- write the tidy register (not committed) ---------------------------------
out <- here::here("data", "curated", paste0("gb_register_", RECEIVED$snapshot_id, ".parquet"))
register_tidy <- register |>
  dplyr::left_join(
    crosswalk |>
      dplyr::transmute(branch = .data$branch, place = .data$register_place,
                       tower_id = as.character(.data$tower_id),
                       ring_id = as.character(.data$ring_id),
                       .data$match_method, reviewed = as.character(.data$reviewed)),
    by = c("branch", "place")
  )
stopifnot("crosswalk does not line up with the register" =
            nrow(register_tidy) == nrow(register))
write_artefact(register_tidy, path = out,
               snapshot_id = c(RECEIVED$snapshot_id, FRAME_SNAPSHOT),
               script = "scripts/C01_import_gb_register.R")
message("Wrote ", out)
