# 05_export_questionnaire_towers.R --------------------------------------------
#
# Generate and PUBLISH the tower list served to the questionnaire.
#
# Everything is written to docs/, which GitHub Pages serves (D-021):
#
#   towers_<snapshot_id>.txt    the list the widget fetches
#   towers_<snapshot_id>.json   manifest: how and when generated, with sha256
#   index.html                  human-readable page, carrying the Dove attribution
#   .nojekyll                   tells Pages to serve files as-is, no Jekyll build
#
# The list is plain text, fetched and parsed as data - never JavaScript (D-016).
# Format:
#   # <snapshot_id> <n_rings> <n_chars>
#   <RingID>|<display>|<alt names>
#
# Integrity is carried as counts, not a checksum: counts catch truncation and a
# partial browser-cache write, HTTPS prevents corruption in transit, and a hash
# cannot detect tampering by anyone able to edit the header too (D-016).
#
# docs/ is committed: it holds exactly what respondents receive.
# .gitattributes forces LF endings, which the character count depends on.

source(here::here("scripts", "00_setup.R"))

SNAPSHOT_ID <- "dove_2026-09-19"          # must match scripts/04_build_frame.R

# Once the questionnaire is live, a published list must never change under the
# URL that respondents' browsers fetch. Set TRUE when fieldwork opens: the
# script will then refuse to alter an existing list, and any change needs a new
# Dove snapshot - and so a new file name and a new URL.
FREEZE_PUBLISHED_LISTS <- FALSE

publish_dir <- here::here("docs")
fs::dir_create(publish_dir)

# ---- load the curated frame -------------------------------------------------

frame_path <- fs::path(here::here("data", "curated"),
                       paste0("frame_", SNAPSHOT_ID, ".parquet"))
stopifnot(fs::file_exists(frame_path))

pick <- arrow::read_parquet(frame_path) |>
  dplyr::filter(.data$frame_picklist) |>
  dplyr::arrange(.data$display)

message("Picker rows: ", format(nrow(pick), big.mark = ","),
        "  (expected 6,297 on dove_2026-09-19 - D-018)")

# ---- checks before anything is written --------------------------------------

# A duplicate display string is unusable in a picker: the respondent cannot
# tell which entry is theirs.
dups <- find_duplicate_displays(pick, display_col = "display", id_col = "ring_id")
if (nrow(dups) > 0) {
  print(dups |> dplyr::select(ring_id, display))
  stop("Colliding display strings. Fix build_display() before publishing.", call. = FALSE)
}

# Pipe-delimited, newline-separated: neither character may appear in a field.
clean <- function(x) {
  x |>
    tidyr::replace_na("") |>
    stringr::str_replace_all("[|\r\n]", " ") |>
    stringr::str_squish()
}

lines   <- paste0(pick$ring_id, "|", clean(pick$display), "|", clean(pick$alt_terms))
payload <- paste0(paste(lines, collapse = "\n"), "\n")
n_chars <- nchar(payload, type = "chars")
text    <- paste0(sprintf("# %s %d %d\n", SNAPSHOT_ID, nrow(pick), n_chars), payload)

# ---- publish the list -------------------------------------------------------

out <- fs::path(publish_dir, paste0("towers_", SNAPSHOT_ID, ".txt"))

if (fs::file_exists(out)) {
  if (identical(readr::read_file(out), text)) {
    message("Published list unchanged: ", fs::path_file(out))
  } else if (FREEZE_PUBLISHED_LISTS) {
    stop("A different list is already published as ", fs::path_file(out),
         " and published lists are frozen. Take a new Dove snapshot rather ",
         "than altering a list respondents may already be using.", call. = FALSE)
  } else {
    message("Replacing ", fs::path_file(out), " (lists not yet frozen).")
  }
}

readr::write_file(text, out)

jsonlite::write_json(
  list(
    generated_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    script           = "scripts/05_export_questionnaire_towers.R",
    snapshot_id      = SNAPSHOT_ID,
    frame_artefact   = fs::path_file(frame_path),
    rule             = "frame_picklist: every ringable ring (D-018)",
    n_rings          = nrow(pick),
    n_chars          = n_chars,
    bytes            = as.numeric(fs::file_size(out)),
    sha256           = file_sha256(out)
  ),
  fs::path(publish_dir, paste0("towers_", SNAPSHOT_ID, ".json")),
  auto_unbox = TRUE, pretty = TRUE
)

# ---- .nojekyll --------------------------------------------------------------
# Without it, Pages runs files through Jekyll, which silently skips anything
# beginning with "_" or "." and adds a build step nothing here needs.

nojekyll <- fs::path(publish_dir, ".nojekyll")
if (!fs::file_exists(nojekyll)) fs::file_create(nojekyll)

# ---- index.html -------------------------------------------------------------
# Regenerated on every run, so the page can never disagree with the files it
# describes. It lists every published list, newest first, not just this one:
# older lists stay published so nothing that points at them breaks.

lists <- fs::dir_ls(publish_dir, regexp = "towers_.+\\.txt$") |> sort(decreasing = TRUE)

list_row <- function(f) {
  head <- strsplit(readLines(f, n = 1, warn = FALSE, encoding = "UTF-8"), " ", fixed = TRUE)[[1]]
  name <- fs::path_file(f)
  flag <- if (identical(head[2], SNAPSHOT_ID)) " <strong>current</strong>" else ""
  sprintf(
    '<tr><td><a href="%s">%s</a>%s</td><td>%s</td><td class="num">%s</td><td class="num">%s KB</td></tr>',
    name, name, flag, head[2],
    format(as.integer(head[3]), big.mark = ","),
    format(round(as.numeric(fs::file_size(f)) / 1024), big.mark = ",")
  )
}

index_template <- r"---(<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ringing Census 2026 - tower lists</title>
<style>
:root{--bg:#fff;--fg:#1d1d1f;--muted:#5f6368;--rule:#e3e3e3;--link:#0b57d0;--code:#f4f4f5}
@media (prefers-color-scheme:dark){:root{--bg:#141414;--fg:#e8e8e8;--muted:#a0a0a0;--rule:#333;--link:#8ab4f8;--code:#1f1f22}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:46rem;margin:0 auto;padding:2.5rem 1rem 4rem}
h1{font-size:1.6rem;line-height:1.25;margin:0 0 .4rem}
h2{font-size:1.1rem;margin:2.2rem 0 .6rem}
.lede{color:var(--muted);margin:0 0 1.5rem}
a{color:var(--link)}
.table-wrap{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:.95rem}
th,td{text-align:left;padding:.45rem .6rem;border-bottom:1px solid var(--rule);white-space:nowrap}
th{font-weight:600;color:var(--muted)}
.num{text-align:right;font-variant-numeric:tabular-nums}
code,pre{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.88em}
pre{background:var(--code);padding:.8rem 1rem;border-radius:6px;overflow-x:auto}
footer{margin-top:3rem;padding-top:1rem;border-top:1px solid var(--rule);color:var(--muted);font-size:.85rem}
</style>
</head>
<body>
<main>
<h1>Ringing Census 2026 &mdash; tower lists</h1>
<p class="lede">The rings offered to respondents when they identify their tower in the
2026 Ringing Census questionnaire, run by the Central Council of Church Bell Ringers.</p>

<h2>Published lists</h2>
<div class="table-wrap">
<table>
<thead><tr><th>File</th><th>Dove snapshot</th><th class="num">Rings</th><th class="num">Size</th></tr></thead>
<tbody>
{{ROWS}}
</tbody>
</table>
</div>
<p>Each list has a companion <code>.json</code> manifest recording how and when it was
generated, with a SHA-256 checksum. Once the questionnaire is live, a published list is
never altered: a changed list is published under a new name.</p>

<h2>Format</h2>
<p>Plain UTF-8 text with Unix line endings. The first line is a header; every other line
is one ring.</p>
<pre># &lt;snapshot&gt; &lt;rings&gt; &lt;characters&gt;
&lt;RingID&gt;|&lt;display name&gt;|&lt;alternative names&gt;</pre>
<p><code>RingID</code> is Dove's ring identifier. Alternative names help searching but are
not shown. The header counts let the questionnaire detect a truncated or partly cached file.</p>

<h2>What is included</h2>
<p>Every ringable ring in Dove's Guide: full-circle rings of any number of bells, and
mini-rings, which are marked as such. Unringable rings, chimes and carillons are not
included. The list is deliberately broader than the census sampling frame, so that
anyone who rings somewhere can find their tower.</p>

<h2>Source and licence</h2>
<p>Tower data from <a href="https://dove.cccbr.org.uk">Dove's Guide for Church Bell Ringers</a>,
&copy; the Central Council of Church Bell Ringers, licensed
<a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>.
Modified: filtered to ringable rings and reformatted. This extract is published under the
same licence. It describes towers and bells only and contains no personal data.</p>

<footer>
Generated by <code>scripts/05_export_questionnaire_towers.R</code> on {{DATE}}.
Source code and decision record:
<a href="https://github.com/cccbr/census2026">github.com/cccbr/census2026</a>
</footer>
</main>
</body>
</html>
)---"

fill <- function(template, key, value) sub(key, value, template, fixed = TRUE)

html <- index_template |>
  fill("{{ROWS}}", paste(purrr::map_chr(lists, list_row), collapse = "\n")) |>
  fill("{{DATE}}", format(Sys.Date(), "%d %B %Y"))

readr::write_file(html, fs::path(publish_dir, "index.html"))

message(sprintf(
  "\nPublished to docs/:\n  %s  (%d rings, %s characters)\n  %s\n  index.html (%d list%s)",
  fs::path_file(out), nrow(pick), format(n_chars, big.mark = ","),
  paste0("towers_", SNAPSHOT_ID, ".json"), length(lists), if (length(lists) == 1) "" else "s"
))
message("\nCommit and push docs/ to publish. GitHub Pages serves it within a minute or two.")
if (!FREEZE_PUBLISHED_LISTS) {
  message("Reminder: set FREEZE_PUBLISHED_LISTS <- TRUE when fieldwork opens.")
}
