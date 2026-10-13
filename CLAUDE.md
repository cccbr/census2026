# CLAUDE.md — Ringing Census 2026

Conventions for any Claude session working in this repository. Read this
before writing code here.

## What this is

Analysis code for the 2026 Ringing Census — a two-stage survey of the
bellringing population of Britain and beyond, run under Ringing 2030 by the
Central Council of Church Bell Ringers (CCCBR). The first such census since
1988. Reference week is 16–22 November 2026.

This repository holds **code, method and provenance records**. It holds no
survey response data and never will.

Owner: Mark Ainsworth (methodology and planning lead). Other contributors
include Bryn (hierarchical propensity model, R and Python, US-based), Elva
(instrument design), Vicki (QuestionPro build).

---

## How to work here

**Mark decides. Claude proposes and advises.** This is not politeness. The
census will be scrutinised by people who will ask why a choice was made, and
Mark has to be able to answer in his own words. A decision Claude made
silently is a decision nobody can defend.

### Default to a proposal, not an implementation

- "Let's discuss", "how should we", "what do you think", "I'm wondering",
  "help me think through" — these ask for **options, trade-offs and a
  recommendation**. They do not ask for files. Answer in prose. Do not
  produce a repo, a script, or a zip.
- "It's time to start coding", "let's gear up to X" — these name a *phase*.
  They are not a green light to produce that phase's output.
- Build when asked to build, in words that name the thing: "write the fetch
  script", "add a function that…", "give me the tower list".
- A deadline mentioned for one deliverable does not authorise building
  everything adjacent to it.
- **When genuinely unsure whether the ask is "discuss" or "do", ask.** One
  sentence. It costs less than unpicking unwanted work.

### When you do build

- One thing at a time, small enough that Mark can read every line that lands.
- Say what you're about to write and why, then write it.
- Do not fix, tidy, rename or extend things that were not asked about.
- Prefer editing a file in place over handing over a bundle.

### Surface decisions, don't resolve them

If code needs a methodological choice — an inclusion rule, a threshold, a
tie-break, a default for a missing value — **stop and ask**. A default buried
in a `filter()` is how an indefensible number reaches a committee paper.

### Argue against before agreeing

When Mark proposes something, give the strongest case against it first, then
your own view. His confidence and seniority are not evidence. Say plainly when
you think he's wrong.

### Be honest about uncertainty

Say what you don't know. Cite sources for empirical claims and quote them. If
your own theory is disproved by evidence, say so directly rather than quietly
moving on to a new one.

---

## Absolute rules

1. **No survey response data in this repository.** Not in a branch, not
   temporarily, not "just to debug it". Git history is effectively permanent
   and one such commit is a reportable personal data breach.
   `.githooks/pre-commit` enforces this. Never suggest `--no-verify` as a
   workaround for a block it raises.

2. **Never read individual-level response data into context.** This holds on
   every Claude surface. Work from schemas, synthetic fixtures and
   aggregates. If a debugging task appears to need real rows, generate a
   fixture that reproduces the shape instead. This is a rule about what is
   asked for, not about which tool is running.

3. **Raw snapshots are immutable.** Nothing in `data/raw/` is edited,
   overwritten or corrected in place. If a snapshot is wrong, take a new one
   and record why.

4. **Reference Dove columns by name, never by position.** Dove states that
   "the number and order of the fields may change from time to time, but we
   will endeavour to keep the column headings stable."

---

## Architecture

```
config/       The named snapshots (snapshots.R) and the provisional choices
              (choices.R). Sourced by scripts/00_setup.R. Every threshold
              and snapshot name lives here, once.
R/            Functions ONLY. Pure. Nothing runs on source().
              If a function here reads a path or writes to disk, it is in the
              wrong place — that belongs in scripts/.
scripts/      The data pipeline, interactive-friendly. All side effects
              live here. These are a narrative, not a library. Named by
              stage and order: A = Dove and the frame, B = settlement
              context, C = association registers. A new step takes the next
              free number in its stage; nothing is renumbered.
questionnaire/  The survey instrument: widget sources (src/), notes, and
              the scripts that publish the tower list and build the paste
              versions of the widgets.
settlement-map/ The volunteers' map: template and publishing script.
analysis/     Quarto sub-project — the analytical narrative.
reports/      Quarto sub-project — parameterised, one render per association.
docs/         What GitHub Pages serves. Generated, committed, never edited.
data/         Only data/reference/ is committed. See README.md.
provenance/   Committed audit trail. Metadata only, never data.
```

Quarto configs are **per sub-project**, not at the repo root. A root
`_quarto.yml` would drag README.md and this file into renders and force
`analysis/` and `reports/` to share output config, which they must not:
`analysis/` freezes renders (`freeze: auto`), `reports/` must not
(`freeze: false`), because a frozen parameterised render will serve one
association's numbers under another association's title.

Abstraction into a function is for genuinely reused things, or genuinely
looped things — the per-association render loop is the canonical example. Do
not wrap a line that is called once. Do not build a helper layer in
anticipation of a need that has not arrived.

---

## Style

- Native pipe `|>` only. No magrittr `%>%`.
- Tidyverse conventions throughout.
- `here::here()` for all paths. No `setwd()`, no relative-path assumptions.
- Comments explain *why*, not *what*. Most odd-looking choices here have a
  methodological reason; record it at the point of the choice.

---

## Writing for people

Everything written here for a human reader follows these rules. That covers
READMEs, Quarto chapters, reports, decision entries and messages to Mark. The
readers are mixed: committee delegates, volunteer analysts, Bryn in Python,
and whoever re-runs this in 2030. Most are not statisticians, and none of them
were in the conversation where a choice was made.

**Lead with the answer.** The first two sentences say what the thing is, what
was found, or what to do. Context comes after.

**One idea per sentence.** Vary the length: a short sentence for a
conclusion, a longer one for the reasoning behind it. Prefer plain words:
"use" not "utilise", "find" not "ascertain".

**Name the actor before the action.** "Script B03 drops these towers", not
"these towers are dropped".

**Be concrete.** Numbers, names, commands and failure conditions, not
adjectives. "Takes about 25 minutes", not "is somewhat slow".

**Make each section stand on its own.** People read the part they need and
skip the rest, and they will not follow a trail of links. Restate the point
where it is needed, briefly, rather than writing "see above", "as discussed"
or "see D-026". A pointer such as a decision ID or file name may *follow* the
restated point, as a reference. It never replaces it. (Code comments are the
exception: there, citing the decision ID at the point it is encoded is the
convention.)

**Define a technical term where it first appears, in that section.** Then
use the same term every time.

**Headings say the point.** "Two dimensions carry 90% of the variation", not
"Results".

**Use a table to compare three or more things.** Not three paragraphs.

**Keep the reasoning.** Be brief in framing, thorough in the *why*. A choice
written without its reason cannot be defended to a delegate.

**Leave out:** preambles that restate what the reader knows; "in this
section", "it is important to note"; closing summaries that repeat the body;
hedges on things that are not uncertain. Say real uncertainty once, plainly.

**For anything others will read, do a second pass** purely for flow and
clarity before handing it over.

An example of the difference:

> *Dense:* Given the absence of discernible multimodality in the joint
> distribution of the settlement metrics, as evidenced by uniformly low mean
> silhouette widths across the evaluated k range, any partitioning should be
> regarded as conventional rather than empirically grounded.
>
> *Clear:* The towers do not fall into natural groups. A silhouette score
> measures how cleanly a clustering separates the data, and ours never rose
> above 0.32, well below the 0.5 usually taken as clear structure. Any classes
> we draw are a convenience for communication, not a discovery.

### Reports and analysis chapters: required opening

Every report, Quarto chapter or analysis document opens with three things,
in this order:

1. **Authorship.** One sentence: "Prepared by Mark Ainsworth with Claude
   (Anthropic). Mark set the questions and made the decisions; Claude drafted
   the code and text, which Mark reviewed." Adjust the wording if the split of
   work was different.
2. **Background and brief.** The question being answered and why it
   matters. Then the guidance, constraints and starting assumptions Mark gave,
   restated plainly in the document's own words, not quoted from a
   conversation. Then what was decided before the work began, and what is out
   of scope. A reader who missed every conversation must be able to follow the
   rest.
3. **Headline findings.** Three to six bullets, computed in the document
   where possible so they stay true when the data changes.

---

## Working with renv

Mark does not use renv daily. **Sessions should actively keep the project
straight rather than assuming the routine is second nature** — prompt for
these, don't wait to be asked.

The one command that prevents most problems is `renv::status()`. It reports
drift between the lockfile, the project library and the code. Run it before
every commit and whenever anything behaves oddly.

| Just happened | Then run |
| --- | --- |
| Installed a package | `renv::snapshot()` |
| Pulled changes touching `renv.lock` | `renv::restore()` |
| Cloned the repo fresh | `renv::restore()` |
| About to commit | `renv::status()` |
| Upgraded R to a new minor version | `renv::restore()` — rebuilds the library for that version |

**The failure that matters:** install a package, use it in a script, never
snapshot. Nothing breaks locally. It breaks on Bryn's machine, or on yours in
2030 when you try to reproduce the 2026 figures. `renv::status()` catches it;
nothing else will.

**Commit `renv.lock`. Never commit `renv/library/`** — renv writes its own
`.gitignore` for that; leave it alone.

**This project runs implicit mode**, so renv discovers dependencies by
scanning code. A stray `library(somepkg)` in an exploratory script becomes a
project dependency at the next snapshot. Keep scratch work out of the repo,
and read what `renv::status()` proposes before accepting it.

**If renv is in the way**, use `renv::deactivate()` and `renv::activate()`
later. Do not delete `renv/` or `.Rprofile` to escape it.

---

## Before any commit

1. `renv::status()` is clean, or you know exactly why it isn't.
2. `git status` shows nothing under `data/` except `data/reference/`.
3. Any methodological decision made in this session is recorded (below).
4. The hook is installed: `git config core.hooksPath .githooks`.

Sessions should run through this with Mark rather than assuming he has.

---

## Decision log and register

Two files, doing different jobs:

- **`provenance/decisions.md`** — append-only history. One entry per
  analytical or data-structure decision: ID, date, status, the decision, the
  alternatives, the reasoning, the evidence. Entries are never edited or
  deleted; a decision that changes gets a new entry and the old one is marked
  `Superseded` with a pointer.
- **`provenance/decision-register.md`** — current state at a glance, plus
  everything still **open**. Maintained by hand.

### Status vocabulary — use it precisely

| Status | Meaning |
| --- | --- |
| **Provisional** | Mark's working decision, taken to allow progress. Not agreed by the project team. Expected to be revisited |
| **Agreed** | Ratified by the project team; the entry names who and when |
| **Open** | Identified, not decided |
| **Superseded** | Replaced by a named later entry |

**Never record a Provisional decision as Agreed**, and never let one reach a
published output silently. Before publication it is either escalated to
`Agreed` or the output itself states that the choice was provisional and what
the alternatives were. Provisional decisions quietly hardening into permanent
ones is the failure this structure exists to prevent.

### Citing decisions in code

Each decision has an ID. Cite it where the decision is encoded:

```r
filter(ring_type == "Full-circle ring")   # D-003
```

That is what makes the log useful rather than decorative — the code says
*what*, the ID leads to *why*.

**Prompt Mark to add an entry whenever a choice made in conversation is about
to be encoded in code.** Draft the entry if he asks, but the reasoning must be
his and he confirms the status: he is the one who will be asked about it.

---

## Provenance discipline

Every raw fetch appends to `provenance/fetch_log.csv` with URL, timestamp,
HTTP status, ETag, bytes, row count and SHA-256. Every curated artefact gets
a `.json` sidecar naming the snapshot and script that produced it —
`write_artefact()` in `R/io.R`.

The test for any table or figure: **"which snapshot is this number from?"**
If it cannot answer, it is not defensible. Delegates have already been
sceptical and will be again.

The sampling frame is a **frozen, stated snapshot**. Scripts name the snapshot
they use explicitly. Nothing silently picks "the latest". Dove changes
continuously; if the frame drifts between building the questionnaire picklist
and running the analysis, responses cannot be matched to frame rows and the
denominator moves.

`renv.lock` is the sibling record: which package versions computed the number.

---

## Data storage

Parquet is the durable artefact and the interchange format — `arrow` in R,
`pyarrow` for collaborators in Python. No database is needed at this scale
(~7,262 towers is a tibble, not a warehouse). DuckDB reads Parquet natively,
so adopting it later for a SQL or reporting layer costs no migration. A
`.duckdb` file, if one ever exists, is a build artefact and is never
committed.

---

## Licensing

Two licences, covering different things.

- **Code**: Apache-2.0, chosen over MIT for §5, which licenses contributions
  under the same terms by default — useful with volunteer contributors and no
  CLA process. Add it via GitHub's own template, never hand-transcribed.
- **Dove's Guide data**: CC BY-SA 4.0. Any redistribution of a substantial
  extract — including the tower array embedded in the questionnaire —
  requires the attribution in `DOVE_ATTRIBUTION` (`scripts/00_setup.R`),
  visible to the end user, not only in this repo.
- **Open legal question, do not assert a position on it:** whether published
  census outputs are "adapted material" under CC BY-SA 4.0 §4, which extends
  to sui generis database rights. Aggregate estimates computed *using* Dove as
  a frame are probably not; a published tower-level dataset carrying Dove
  fields very likely is. Pending sign-off alongside the DPIA.

---

## Disclosure control

Association-level and tower-level outputs are a disclosure-control problem
before they are a presentation problem. A tower with four ringers reporting
age band and sex is re-identifiable.

Suppression rules live in `R/disclosure.R` and are applied in the **data
layer**, never in a report or app. The moment suppression lives in a
presentation layer, someone exports the underlying table.

Onward disclosure to associations is itself processing the DPIA must cover.

---

## Decisions — read the register, don't rely on this file

**`provenance/decision-register.md` is the single source of truth for what has
been decided and what is open.** It is not duplicated here, deliberately: two
lists of decisions drift apart, and the stale one gets believed.

Read it at the start of any session that will touch the frame, the
questionnaire, the crosswalk or any published figure.

Two things worth knowing without looking:

- **As of 2026-09-30, the core frame decisions are `Agreed`** by the committee
  (D-017 bell count, D-018 picker scope, D-019 international). Several others
  remain Provisional — check the register before relying on any of them.
- The frame key is **`RingID`**, not `DoveID` (D-007). An earlier version of
  this file said Dove ID; that was wrong — `DoveID` is blank for 118 rings and
  `TowerID` is not unique.

If code needs a decision the register lists as **Open**, ask. Do not pick a
default and bury it in a filter.

### Repository conventions, which are not decisions

These live here because they are tooling, not method:

- `renv` runs in **implicit mode**. `renv.lock` is authoritative;
  DESCRIPTION's `Imports:` is a hint for humans and may drift.
- Society name → Dove affiliation mapping is a **committed, hand-checked
  crosswalk** in `data/reference/`. Fuzzy matching may propose; a human
  disposes. No mapping enters because a string distance was below a threshold.
- Association reporting is parameterised Quarto, one report per association,
  delivered to a named officer — not an authenticated Shiny app. Shiny is for
  the analysis team's internal exploration only.

---

## Environment

Windows 11, Positron, R 4.6.1. Positron does not use `.Rproj` files —
project-hood comes from `.git/`, `DESCRIPTION` and `renv.lock`, and paths from
`here::here()`. The repo deliberately works in any IDE; Bryn may be
Python-first.

Traps already hit once, worth not hitting again:

- **The repo must not live under OneDrive.** Sync clients corrupt `.git` and
  make `renv/library` (thousands of small files) unusable. It now lives at
  `C:\Users\mark\dev\ringing-census-2026`. Do not suggest moving it back.
- **`R_LIBS_USER` follows the running session's R version.** A fresh R minor
  version has no user library directory, and R only adds the path to
  `.libPaths()` if the directory already exists — so `install.packages()`
  falls back to the unwritable system library. Fix is
  `dir.create(path.expand(Sys.getenv("R_LIBS_USER")), recursive = TRUE)`, then
  restart. Never install into `Program Files` or run the IDE as administrator.
- **Positron binds an interpreter per workspace.** If the wrong R version
  starts, delete the session (trash icon in the console header) and start a
  new one. Check `R.version.string` before any install.
- **When something is wrong with the IDE, read the Output panel first.**
  Positron's R Supervisor and R Language Pack channels diagnose in seconds
  what is otherwise a long guess from symptoms.

---

## Current state (11 October 2026)

Pushed to `cccbr/census2026`; the pre-commit hook is installed. The frame
(`frame_dove_2026-09-19`) and the questionnaire tower list are built.

Settlement context is in progress, toward choosing how to stratify the chased
sample (Q-023, needed before the draw):

- Script B01 builds tower locations. Script B02 fetches GHSL population, GHSL
  Degree of Urbanisation, GHSL land and ONS RUC 2021 (all snapshots dated
  2026-10-10). Script B03 builds `tower_context_dove_2026-09-19.parquet`,
  now with 250 m and 500 m measures and contiguous-settlement measures
  (D-027). Mark re-runs 08 on his machine.
- The analysis book has four settlement chapters sharing
  `analysis/_common.R`: `tower-context.qmd` (the measures and their
  structure), `bells-remember.qmd` (side quest: ring size against the
  measures, scales, decision trees, frontier model, walking-world idea),
  `settlement-classes.qmd` (1988 shares, Drafts A and B set aside, Draft C,
  known-towers sense check) and `sampling-design.qmd` (design simulation).
- The classification is place-only (D-028), and its scales are chosen to
  describe places today, never because they fit ring size (D-035). Draft C
  (D-037): towns and villages by people per km² of land in the 250 m kernel
  (the walkable population; town 600, village 200); inside urban centres, a
  centre if within 250 m of a CDRC retail centre of District Centre size or
  larger, or among 3+ towers (abroad, the non-residential share of buildings
  against the urban centre's own, D-036); neutral type names; tower
  clusters (5+ towers within 1 km) a flag. `beyond_walk` (density between
  the 250 m and 2 km kernels) is a measure, not a type. Names must not
  grade places: people will look up their own town (Mark's father's
  warning). Draft B is kept in the chapter only as the account of where it
  ran aground.
- Script B04 builds `tower_retail_dove_2026-09-19.parquet` from the CDRC
  Retail Centre Boundaries (snapshot `cdrc_retail_2026-10-11`, Open
  Government Licence; attribution in the map footer). `_common.R` needs it.
- The Gloucester & Bristol Association's 2025 tower register (ringers per
  tower, from its treasurer) is imported by `scripts/C01_import_gb_register.R`.
  Its counts are third-party data and stay in `data/raw` and `data/curated`,
  never in the public repo (Q-025); only the name-to-Dove crosswalk is
  committed. See `data/reference/gb_register.md`.
- `data/reference/known_towers.csv` holds towers people know, with what each
  feels like. A draft special-case tower list (81 rows, all `proposed`) is in
  `data/reference/special_towers_draft.csv` (Q-022).

Still outstanding:

- `scripts/A04` (society crosswalk) is not written; it waits on Q-006.
- The QuestionPro widgets live in `questionnaire/`: the single picker
  `tower_autocomplete.js` and the multi picker `tower_multipicker.js`
  (D-030). **Never hand Mark a source file to paste.** QuestionPro refuses
  JavaScript Logic above a limit between 19,012 and 20,841 characters, so
  `questionnaire/build_widgets.R` strips comments into
  `questionnaire/build/*.paste.js` (gitignored). `foldKey()` now has
  three copies (both widgets and `R/text.R`) that must change together.
  Platform behaviour learned the hard way is in `tower-autocomplete.md`;
  read it before changing either widget.
