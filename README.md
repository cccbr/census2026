# Ringing Census 2026

This repository holds the code for the 2026 Ringing Census. It builds the
sampling frame of towers, publishes the tower list the questionnaire uses,
prepares the settlement measures that guide the sample, and will hold the
analysis. It never holds survey responses.

The census is run by the Central Council of Church Bell Ringers (CCCBR) under
Ringing 2030. It is the first count of the bellringing population since 1988.
The reference week is 16–22 November 2026.

*Written by Mark Ainsworth with Claude (Anthropic). Mark sets the direction
and makes the decisions; Claude drafts much of the code and text, which Mark
reviews.*

---

## Getting started

You need R 4.6 or later, Quarto, and git. From the repository root:

```r
renv::restore()                          # install the exact package versions
```

```bash
git config core.hooksPath .githooks      # turn on the safety checks
```

Then run the scripts in order, as described below. Each script that fetches
data needs network access, and each takes a dated snapshot, so re-running one
on the same day stops rather than overwriting.

---

## The pipeline, script by script

Scripts live in `scripts/` and are numbered in the order they run. Each one
names the data snapshot it uses at the top. None of them silently picks "the
latest".

| Script | What it does | Writes | Time |
| --- | --- | --- | --- |
| `00_setup.R` | Loads packages and the functions in `R/`. Every script starts by sourcing it | — | seconds |
| `01_fetch_dove.R` | Downloads Dove's Guide, the tower database | `data/raw/dove/<date>/`, a row in the fetch log | 1 min |
| `02_profile_dove.R` | Records the columns Dove actually had, so a change in Dove shows up in a diff | `provenance/dove_schema_<snapshot>.md` | seconds |
| `03` | Society crosswalk. **Not yet written** | — | — |
| `04_build_frame.R` | Builds the frame: one row per ring of bells, with flags for each frame definition | `data/curated/frame_<snapshot>.parquet` | seconds |
| `05_export_questionnaire_towers.R` | Publishes the tower list the questionnaire's search box fetches | `docs/` (served by GitHub Pages) | seconds |
| `06_build_tower_locations.R` | One row per tower with its coordinates | `data/curated/tower_locations_<snapshot>.parquet` | seconds |
| `07_fetch_geography.R` | Downloads population, land and urban–rural data. Set `SOURCES_TO_FETCH` at the top to choose which | `data/raw/<source>/<date>/` | 5–15 min |
| `08_build_tower_context.R` | Measures each tower's surroundings: people, other towers and bells nearby, land and sea, the continuous settlement it stands in, urban–rural class | `data/curated/tower_context_<snapshot>.parquet` | 25–35 min |
| `09_build_widget_paste.R` | Strips comments from the two QuestionPro widgets so they fit QuestionPro's script size limit (between 19,012 and 20,841 characters). Paste these builds, never the source | `inst/questionnaire/build/*.paste.js` | seconds |
| `10_export_settlement_map.R` | Publishes an interactive map of the draft settlement types, for volunteers to check | `docs/settlement-map/index.html` (served by GitHub Pages) | seconds |

### What the settlement measures are

Script 08 describes the area around each tower in three ways.

- **A decay kernel** counts people, towers or bells, giving nearer ones more
  weight. The weight halves every 250 m, 500 m, 1, 2, 4 or 8 km depending on
  the version. The 2 km version is the main catchment measure, chosen from
  published data on how far people travel to weekly voluntary activities.
- **A plain circle** counts everything within 500 m, 1, 2, 5 or 10 km. It is
  easier to explain, but its edge is arbitrary.
- **A contiguous settlement** is the continuous built-up area the tower
  stands in, traced on the international Degree of Urbanisation grid with
  that scheme's own rules, with the number of people in it. Unlike the
  kernels and circles, it follows the settlement's own edge, so it can tell a
  free-standing city from a suburb.

From these it derives people per tower, people per bell, people per km² of
land, and how much of the area is sea. It also records two ready-made
urban–rural classes for comparison: the international Degree of Urbanisation
(from the EU's Global Human Settlement Layer) and, for England and Wales, the
ONS 2021 Rural Urban Classification.

Measure names follow one pattern: `k` for kernel or `r` for circle, then the
distance (`k250m`, `r2km`). Only the helpers in `R/catchment.R` read these
names; nothing else should parse them.

The reasoning, and the alternatives considered, are in decisions D-026 and
D-027 in `provenance/decisions.md`.

---

### The settlement map

`docs/settlement-map/index.html` is an interactive map of every frame tower,
coloured by its draft settlement type, with the measures behind each type in
a popup. It is for the analysis volunteers to pan around and challenge. Once
pushed, GitHub Pages serves it at `<pages site>/settlement-map/`. It is one
self-contained file, so it also opens straight from disk.

Script 10 builds it from the same code as the analysis chapters
(`analysis/_common.R`), so the map always shows the current classification.
Re-run script 10 after changing the classification or re-running script 08,
then commit the page. It contains no personal data, and carries Dove's
CC BY-SA attribution.

---

## Where data lives, and what is committed

| Folder | Committed? | What it holds |
| --- | --- | --- |
| `data/raw/` | No | Downloads exactly as received, in dated folders. Never edited |
| `data/interim/` | No | Unzipped and intermediate files. Safe to delete; scripts rebuild them |
| `data/curated/` | No | The tables the analysis uses, as Parquet files |
| `data/reference/` | **Yes** | Small hand-checked tables that are part of the method, such as the draft special-case tower list |
| `provenance/` | **Yes** | The audit trail: fetch log, schema notes, decision log |
| `docs/` | **Yes** | The published tower list, exactly as respondents receive it |

**Why the data is not committed but its description is.** Every download adds
a row to `provenance/fetch_log.csv` with its address, time, size and SHA-256
checksum. Anyone holding a copy of a snapshot can prove it is the one used,
without the data ever entering git. Every curated table also has a `.json`
file beside it naming the snapshots and script that made it. The test for any
published number is "which snapshot is this from?", and these records answer
it.

**Why snapshots are frozen.** Dove changes every week. If the frame shifted
between building the questionnaire list and analysing the replies, replies
could not be matched to towers and the denominator would move.

**Parquet** is the storage format: R reads it with `arrow`, Python with
`pyarrow`. At about 7,300 rings no database is needed.

### No survey responses, ever

No survey response data enters this repository: not in a branch, not briefly,
not "just to debug". Git keeps history permanently, and one such commit would
be a reportable personal data breach. The pre-commit hook in `.githooks/`
blocks files over 1 MiB, anything under `data/` outside `data/reference/`, and
files with personal-data column names. Do not bypass it.

---

## Analysis and reports

Both are Quarto projects, each in its own folder with its own `_quarto.yml`.

- **`analysis/`** is the analytical narrative, rendered as a book. Render it
  with `quarto render analysis/`. It caches results in `analysis/_freeze/`, so
  only changed chapters re-run. Three chapters prepare the chased sample:
  *Towers and the places they stand in*, *Choosing a classification* and
  *Choosing a sampling method*. They share data, provisional choices and the
  working classification through `analysis/_common.R`.
- **`reports/`** will produce one report per ringing association, from one
  template. It never caches, because a cached run would show one
  association's numbers under another's name.

Rendered output and caches (`_output/`, `_freeze/`) are not committed. They
contain computed results, and they can always be rebuilt from code plus the
named snapshots.

**The cache does not notice everything.** Quarto re-runs a chapter only when
the chapter's own file changes. It does not notice a change to
`analysis/_common.R`, to a function in `R/`, or to the data (for example
after re-running script 08). After any of those, either:

- render the affected chapters one at a time, for example
  `quarto render analysis/settlement-classes.qmd`. Rendering a single file
  always re-runs its code, frozen or not; or
- delete `analysis/_freeze/` and render the whole book.

`--cache-refresh` does not do this: it refreshes knitr's chunk cache, which
this project does not use, not Quarto's freeze.

**Preview renders the whole book.** Preview (the button, or `quarto
preview`) serves the entire book and renders every chapter that needs it. To
work on one chapter, use `quarto render` on that file instead.

Two set-up details make rendering work, because Quarto runs R from inside
each folder rather than the repository root:

- Each folder has an `.Rprofile` that switches on the project's renv library.
  Without it, R cannot find `knitr` or `rmarkdown`.
- Each chapter starts with `here::i_am("analysis/<file>.qmd")`, so file paths
  resolve from the repository root.

---

## Decisions: where to find what was decided

Two files in `provenance/` record decisions.

- **`decisions.md`** is the history. Each entry gives the decision, its
  status, the alternatives and the reasoning. Entries are never edited; a
  changed decision gets a new entry.
- **`decision-register.md`** is the current state, plus every question still
  open.

Each decision has one of four statuses:

| Status | Meaning |
| --- | --- |
| Provisional | Mark's working decision, made to allow progress |
| Agreed | Ratified by the project team, who are named |
| Open | Identified, not yet decided |
| Superseded | Replaced by a named later entry |

Code cites the decision it encodes, for example `# D-017` beside the rule
for four or more bells, so the reason is one search away.

---

## Code conventions

- `R/` holds functions only. Nothing in it runs when sourced, reads a file or
  writes to disk. Anything with side effects belongs in `scripts/`.
- Native pipe `|>`, tidyverse style, `here::here()` for every path.
- Dove's columns are always referred to by name. Dove warns that their order
  may change.
- Comments explain *why*. Most odd-looking choices have a methodological
  reason, recorded where the choice is made.

Contributors using Claude will find more detailed working rules in
`CLAUDE.md`, including how prose in this repository should be written.

---

## Things that have gone wrong before

| Problem | Fix |
| --- | --- |
| The repository was inside OneDrive, which corrupted git and renv | Keep it outside synced folders. It now lives at `C:\Users\mark\dev\ringing-census-2026` |
| A new R version could not install packages | Create the user library folder, then restart R: `dir.create(path.expand(Sys.getenv("R_LIBS_USER")), recursive = TRUE)` |
| Positron started the wrong R version | Delete the console session (bin icon) and start a new one. Check `R.version.string` before installing anything |
| Quarto said `knitr` or `rmarkdown` was missing | The folder's `.Rprofile` is missing; renv was not active |
| Quarto could not find `scripts/00_setup.R` | The chapter lacks its `here::i_am()` line |
| Script 08 stopped on a GHSL land tile's extent | Fixed. Land tiles are trimmed where mostly sea; the check now accepts that |
| A chapter showed old numbers after script 08 was re-run | The freeze does not notice data changes. Render each chapter on its own, or delete `analysis/_freeze/` first |

After installing a package, run `renv::snapshot()`. Before committing, run
`renv::status()`. A package used but never snapshotted works on your machine
and fails on everyone else's.

---

## Licences and attribution

**Code:** Apache-2.0 (see `LICENSE`). It was chosen over MIT because its §5
licenses every contribution on the same terms by default, which suits a
volunteer project with no contributor agreement.

**Dove's Guide:** CC BY-SA 4.0. Wherever a Dove extract is redistributed,
including the questionnaire's tower list, it must carry this attribution
(the text is `DOVE_ATTRIBUTION` in `scripts/00_setup.R`):

> Tower data from Dove's Guide for Church Bell Ringers
> (<https://dove.cccbr.org.uk>), © the Central Council of Church Bell Ringers,
> licensed CC BY-SA 4.0.

One question is open and awaiting legal sign-off: whether published census
results count as "adapted material" under the licence's ShareAlike terms.
Totals estimated *using* Dove as a frame probably do not. A published
tower-by-tower table carrying Dove fields very likely does, and would then have
to be released under CC BY-SA 4.0 too.

**GHSL** (population, land, Degree of Urbanisation): © European Union. Reuse
is authorised provided the source is acknowledged. Cite Schiavina et al.
(2023), GHS-POP and GHS-SMOD R2023A, and GHS-LAND R2022A.

**ONS boundaries and Rural Urban Classification:** Open Government Licence
v3.0. Contains OS data © Crown copyright and database right.
