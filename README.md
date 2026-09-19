# Ringing Census 2026

Analysis code for the 2026 Ringing Census — a two-stage survey of the
bellringing population, run under Ringing 2030 by the Central Council of Church
Bell Ringers. The first such census since 1988.

This repository holds **code, method and provenance records**. It holds no
survey response data and never will.

---

## Licensing

There are two licences here and they cover different things.

### Code

Apache-2.0 (see `LICENSE`). Chosen over MIT for §5, which makes every
contribution licensed under the same terms by default — useful for a volunteer
project with no CLA process.

> **Add the licence via GitHub's own template** (Add file → Choose a license
> template → Apache License 2.0). Hand-transcribed licence text is a bad idea;
> the template inserts the canonical wording and the right copyright line.

### Data

Dove's Guide data is **CC BY-SA 4.0**. From
<https://dove.cccbr.org.uk/downloads>:

> "you must give appropriate credit, provide a link to the licence, and
> indicate if changes were made"

> "If you remix, transform, or build upon the data, you must distribute your
> contributions under the same license as the original."

Three consequences:

1. **Attribution is required wherever a Dove extract is redistributed** —
   including the tower array embedded in the questionnaire. The required text
   is `DOVE_ATTRIBUTION` in `scripts/00_setup.R`. It must appear in the
   survey's about/privacy text, not only in this repo.

2. **The ShareAlike scope is an open legal question and needs answering before
   publication.** CC BY-SA 4.0 §4 extends to sui generis database rights, and
   extracting a substantial portion produces "adapted material". Aggregate
   population estimates computed *using* Dove as a frame are probably not an
   adaptation; a published tower-level dataset carrying Dove fields very likely
   is, and would have to be released CC BY-SA 4.0. This is not settled here —
   it goes to the project's legal/DP sign-off alongside the DPIA.

3. **The code licence is unaffected.** Code that reads a CC BY-SA database is
   not a derivative of it.

---

## The data contract

```
data/raw/        NOT COMMITTED   immutable, dated, checksummed snapshots
data/interim/    NOT COMMITTED   derived, disposable
data/curated/    NOT COMMITTED   parquet — the frame, the analysis tables
data/reference/  COMMITTED       hand-curated lookups: part of the method
provenance/      COMMITTED       fetch log, schema notes — the audit trail
```

**Parquet is the durable artefact and the interchange format.** R via `arrow`,
Python via `pyarrow`. No database is required at this scale — 7,262 towers is
a tibble, not a data warehouse. DuckDB reads Parquet natively, so adopting it
later for the reporting layer costs nothing and requires no migration. If a
`.duckdb` file ever exists it is a build artefact, rebuilt from scripts,
never committed.

**The audit trail is committed; the data is not.** `provenance/fetch_log.csv`
records the URL, timestamp, SHA-256, byte count and row count of every raw
fetch. Anyone can verify a snapshot from this repo alone without the repo ever
containing the data. Every curated artefact carries a `.json` sidecar naming
the snapshot and script it came from. If you cannot answer "which snapshot is
this number from?", the number is not defensible to a sceptical delegate.

### Freezing the frame

Dove changes continuously. The sampling frame must be a **stated snapshot,
frozen on a stated date**. If the frame drifts between building the
questionnaire picklist and running the analysis, responses cannot be reliably
matched to frame rows and the denominator moves. Scripts name the snapshot they
use explicitly; nothing silently picks "the latest".

### Personal data

No survey response data enters this repository, at any stage, in any form,
including in a branch, including temporarily, including "just to debug it".
Git history is effectively permanent and a single such commit is a reportable
breach.

This is enforced mechanically rather than by discipline. Install the hook once
per clone:

```bash
git config core.hooksPath .githooks
```

It blocks files over 1 MiB, anything under `data/` outside `reference/`, and
text files carrying personal-data-shaped column names.

---

## Repository conventions

```
R/            Functions ONLY. No side effects, nothing runs on source().
scripts/      Numbered, run top-to-bottom, interactive-friendly. All side
              effects live here.
analysis/     Quarto — the analytical narrative.
reports/      Parameterised Quarto: one report per association.
inst/         Generated assets (the questionnaire tower array).
provenance/   Committed audit trail.
```

The rule that makes this work: **if a function in `R/` reads a file path or
writes to disk, it is in the wrong place.** Keeping `R/` pure also means the
scripts can be lifted into `targets` later without rewriting anything, should
the "is this artefact current?" question ever start to hurt.

Abstraction into functions is for genuinely reused or genuinely looped things —
not for wrapping a line you call once.

### Style

- Native pipe `|>` only.
- Tidyverse conventions.
- Reference Dove columns **by name, never by position**. Dove states the field
  order may change.

### Reproducibility

`renv` from the first commit. A census that cannot be re-run in 2030 to compare
with 2026 has failed its own comparability requirement.

```r
renv::init()      # once
renv::snapshot()  # after adding a dependency
renv::restore()   # on a fresh clone
```

---

## Running it

```r
source("scripts/01_fetch_dove.R")     # immutable snapshot + provenance
source("scripts/02_profile_dove.R")   # schema note -> provenance/
# 03-05 follow once the schema note is in hand
```

Note: `01` needs network access. It will not run in a sandboxed environment
whose egress policy blocks `dove.cccbr.org.uk`.

---

## Attribution

Tower data from Dove's Guide for Church Bell Ringers
(<https://dove.cccbr.org.uk>), © the Central Council of Church Bell Ringers,
licensed CC BY-SA 4.0.
