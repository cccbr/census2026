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
R/            Functions ONLY. Pure. Nothing runs on source().
              If a function here reads a path or writes to disk, it is in the
              wrong place — that belongs in scripts/.
scripts/      Numbered, run top-to-bottom, interactive-friendly. All side
              effects live here. These are a narrative, not a library.
analysis/     Quarto sub-project — the analytical narrative.
reports/      Quarto sub-project — parameterised, one render per association.
inst/         Generated assets (the questionnaire tower array).
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

## Decision log

`provenance/decisions.md`, append-only. One entry per methodological decision:
date, the decision, the alternatives considered, the reason, who decided.

This exists because the question actually asked in 2027 will not be "what did
you do?" — the code answers that — but "why that way, and did you consider X?"
A decision that cannot be reconstructed is a decision that cannot be defended.

**Prompt Mark to add an entry whenever a choice made in conversation is about
to be encoded in code.** Do not write entries on his behalf without asking:
the reasoning has to be his, in his words, because he is the one who will be
asked about it.

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

## Decided

- Frame source is `dove.csv` (full-circle rings), not `towers.csv`.
- Questionnaire picklist = the frame exactly, plus an explicit "my tower isn't
  listed" free-text escape. Picklist and frame do not diverge; the escapes
  become an auditable reconciliation task.
- The survey captures the **Dove ID**, not a tower name string. Names are
  neither stable nor unique.
- Association reporting is parameterised Quarto, one report per association,
  delivered to a named officer. Not an authenticated Shiny app — ~65
  associations of authentication is hosting cost plus an indefinite DP
  surface. Shiny is for the analysis team's internal exploration only.
- Society name → Dove affiliation code mapping is a **committed, hand-checked
  crosswalk** in `data/reference/`. Fuzzy matching may propose; a human
  disposes. No mapping enters because a string distance was below a threshold.
- `renv` runs in **implicit mode**. `renv.lock` is authoritative;
  DESCRIPTION's `Imports:` is a hint for humans and may drift.

## Not decided — do not assume a default

- **Frame inclusion rules**: minimum bell count, treatment of unringable
  towers, geographic boundary of "Britain and beyond".
- **Branch / district source**: this attribute does not exist in Dove. Either
  associations supply a branch→tower lookup, or it is collected in the
  survey. Collecting it as free text from tower representatives will produce
  forty spellings of each district.
- The ShareAlike question above.

If code needs one of these, ask. Do not pick a default and bury it in a
filter.

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

## Current state (19 September 2026)

Skeleton in place. Git initialised, no commits yet. Not yet pushed — CCCBR
org membership pending, so `origin` is unset.

Outstanding, roughly in order:

1. `renv::init()` is **incomplete** — `renv/settings.json` exists but there is
   no `renv.lock` and no `.Rprofile`, so renv is not active. Finish it.
2. `analysis/` and `reports/` are empty — the Quarto sub-project configs have
   not been added.
3. `LICENSE` is absent. Add via GitHub's Apache-2.0 template.
4. Install the pre-commit hook: `git config core.hooksPath .githooks`.
5. Set `git config user.email` before the first commit — every commit carries
   it in perpetuity and the repo is destined for a CCCBR org.
6. `provenance/decisions.md` does not exist yet.
7. `scripts/01_fetch_dove.R` has not been run; `provenance/fetch_log.csv` does
   not exist yet.
8. Scripts 03–05 (society crosswalk, frame build, questionnaire export) are
   not written. They are blocked on the schema note from
   `scripts/02_profile_dove.R` and on the frame inclusion rules above.
