# Status

Where the work stands. Update this file, not `CLAUDE.md`, as things move.

## As at 13 October 2026

Pushed to `cccbr/census2026`; the pre-commit hook is installed. The frame
(`frame_dove_2026-09-19`) and the questionnaire tower list are built.

Settlement context is in progress, toward choosing how to stratify the chased
sample (Q-023, needed before the draw):

- Script B01 builds tower locations. Script B02 fetches GHSL population, GHSL
  Degree of Urbanisation, GHSL land and ONS RUC 2021 (all snapshots dated
  2026-10-10). Script B03 builds `tower_context_dove_2026-09-19.parquet`,
  now with 250 m and 500 m measures and contiguous-settlement measures
  (D-027). Mark re-runs B03 on his machine.
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
- `scripts/B05_build_tower_classes.R` saves the Draft C classification to
  `tower_classes_dove_2026-09-19.parquet`; the map reads it, and the sample
  draw should too. The thresholds are in `config/choices.R`.
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
  `questionnaire/paste/*.paste.js` (committed). `foldKey()` now has
  three copies (both widgets and `R/text.R`) that must change together.
  Platform behaviour learned the hard way is in `questionnaire/README.md`;
  read it before changing either widget.
