# 09_build_widget_paste.R -----------------------------------------------------
#
# Build the paste versions of the two QuestionPro widgets.
#
#   inst/questionnaire/tower_autocomplete.js  ->  build/tower_autocomplete.paste.js
#   inst/questionnaire/tower_multipicker.js   ->  build/tower_multipicker.paste.js
#
# QuestionPro rejects JavaScript Logic above a limit somewhere between 19,012
# characters (accepted) and 20,841 (rejected), found by test on 2026-10-10.
# The comments carry the reasons for the code, so they stay in the committed
# source, and this script removes them for pasting.
#
# Only WHOLE-LINE // comments and blank lines are removed. A comment after code
# on the same line is kept, because telling it apart from "//" inside a string
# or URL needs a JavaScript parser - and a broken paste in QuestionPro is slow
# to diagnose.
#
# build/ is gitignored. Before fieldwork, compare what is deployed in
# QuestionPro with a fresh build from this script, not with the source.

source(here::here("scripts", "00_setup.R"))

# The largest script QuestionPro is known to accept. A build above it is
# refused here rather than discovered in the QuestionPro editor.
PASTE_LIMIT <- 19012

src_dir   <- here::here("inst", "questionnaire")
build_dir <- fs::path(src_dir, "build")
fs::dir_create(build_dir)

widgets <- c("tower_autocomplete", "tower_multipicker")

for (w in widgets) {
  src  <- fs::path(src_dir, paste0(w, ".js"))
  out  <- fs::path(build_dir, paste0(w, ".paste.js"))
  code <- readr::read_lines(src)

  version <- stringr::str_match(code, 'version:\\s*"([^"]+)"')[, 2] |>
    purrr::discard(is.na) |>
    dplyr::first()

  keep <- !stringr::str_detect(code, "^\\s*//") & stringr::str_detect(code, "\\S")
  body <- stringr::str_remove(code[keep], "\\s+$")

  header <- paste0("// ", w, " ", version, " - PASTE BUILD of inst/questionnaire/",
                   w, ".js. Do not edit; rebuild with scripts/09.")
  paste_lines <- c(header, body)

  # LF endings, so the character count is the same on Windows as in QuestionPro.
  readr::write_lines(paste_lines, out, sep = "\n")

  n_chars <- sum(nchar(paste_lines, type = "chars")) + length(paste_lines)
  message(sprintf("%-20s %-6s %6s chars (source %6s)  -> %s",
                  w, version, format(n_chars, big.mark = ","),
                  format(sum(nchar(code, type = "chars")) + length(code), big.mark = ","),
                  fs::path_rel(out, here::here())))

  if (n_chars > PASTE_LIMIT) {
    stop(w, ".paste.js is ", n_chars, " characters, above the ", PASTE_LIMIT,
         " QuestionPro is known to accept. Trim the code, or test a larger ",
         "paste and update PASTE_LIMIT with the result.")
  }
}
