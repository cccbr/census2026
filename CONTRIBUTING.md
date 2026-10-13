# Contributing

How to work on this repository without tripping over anyone else. Read
`README.md` first for what the project is and how the pipeline runs, and
`CLAUDE.md` for the conventions every change follows.

## Set up once

1. Clone the repository somewhere **outside** OneDrive or any other sync
   folder. Sync clients corrupt `.git` and the package library.
2. Turn on the local guard: `git config core.hooksPath .githooks`. It stops a
   commit that contains large files, data outside `data/reference/`, or
   personal-data-shaped columns. The same check runs on GitHub for every pull
   request, so skipping this step only means finding out later.
3. In R, from the repository root: `renv::restore()`. This installs the
   package versions in `renv.lock`.

## Getting the data

The repository holds code, method and provenance records, never data. Raw
snapshots and curated tables are rebuilt by the scripts in `scripts/`.
Rebuilding everything takes about 45 minutes and needs downloads that require
registration (the CDRC retail centres), so ask Mark for the curated tables
instead. Put them in `data/curated/`.

The Gloucester & Bristol register's counts are third-party data. They are
never committed: this repository is public. Access to them is agreed with
the Association; who may hold them is still being settled (Q-025).

## Making a change

1. **Branch.** Never commit to `main` directly. Name the branch for the
   change: `crosswalk-q006`, `map-legend`.
2. **One topic per pull request.** A reviewer should be able to say what it
   does in one sentence. Moving files and changing what they do belong in
   separate commits.
3. **Pull often** (`git pull --rebase` on your branch), and run
   `renv::restore()` whenever `renv.lock` changes.
4. **Open a pull request.** Mark reviews anything that touches `config/`,
   `provenance/`, `questionnaire/`, `docs/`, `apps/` or
   `CLAUDE.md`.

## Rules that prevent most conflicts

| Situation | Rule |
| --- | --- |
| Changing a threshold or measure | Edit `config/choices.R` only, and cite the decision (D-) or open question (Q-) it rests on next to the line |
| Using a new data snapshot | Edit `config/snapshots.R` only, in a commit of its own |
| Proposing a decision | Add an entry at the end of `provenance/decisions.md` headed `## D-NEXT — <title>`, status **Provisional**. Mark assigns the number when merging, so two branches never claim the same one |
| Adding a package | One package change per pull request, with `renv::snapshot()`. Say why in the description |
| Generated files (`docs/`, `questionnaire/paste/`) | Regenerate them in the same pull request as the change that causes them. If two branches conflict on one, re-run its script; never merge it by hand |
| Adding a pipeline step | Take the next free number in its stage (A: Dove and the frame, B: settlement context, C: association registers). Never renumber |
| Adding a page for people to look at | A new folder `apps/<name>/` with its template and publishing script, writing to `docs/<name>/` |
| `CLAUDE.md` | Stable conventions only. Progress notes go in `STATUS.md` |

## Never

- Commit survey responses, register counts or any personal data, even
  briefly. Git history is effectively permanent, and the repository is
  public.
- Use `git commit --no-verify` to get past the guard. If it blocks something
  you believe is safe, ask.
