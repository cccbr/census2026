# CCCBR society membership, 2025 and 2026

Metadata for `cccbr_society_membership_2025-2026_acm2026-p58.csv`.

## Source

Central Council of Church Bell Ringers, *Annual Council Meeting 2026 Meeting
Papers*, page 58, table "Society Membership Numbers August 2026".

Local copy of the source page: `CCCBR-Annual-Council-Meeting-2026-Meeting-Papers (page 58).pdf`
(extracted from the full meeting papers PDF in the same folder). Not held in
this repository — the PDF is a CCCBR document, not ours to redistribute.

## How it was produced

Transcribed from the PDF page by Google Gemini (date of transcription
unrecorded; file mtime 2026-09-19). Column headings were subsequently renamed
to lower snake_case for R compatibility — the originals began with digits
(`2025_Members`), which require backtick-quoting in R. No values were altered.

Original column names, in order: `Category`, `Society`, `2025_Members`,
`2026_Members`, `2026_Reps`, `2026_Vacancies`.

## Columns

| Column | Meaning |
| --- | --- |
| `category` | `Affiliated`, `Associated` or `Small` — the Council's own membership classes |
| `society` | Society name **as printed in the ACM paper**. Not a Dove affiliation string and not a join key; see below |
| `members_2025` | Members reported for 2025, as restated in the 2026 paper |
| `members_2026` | Members reported for 2026 |
| `reps_2026` | Council representatives held in 2026 |
| `vacancies_2026` | Unfilled representative seats in 2026 |

70 rows: 55 Affiliated, 7 Associated, 8 Small.

## Verification

The paper prints its own control totals, so the transcription can be audited
without re-reading the page. Checks run on 2026-09-19:

| Check | Transcribed | Paper | Result |
| --- | --- | --- | --- |
| Affiliated societies | 55 | 55 (163 reps + 21 vacancies = 184 seats) | PASS |
| Affiliated reps | 163 | 163 | PASS |
| Affiliated vacancies | 21 | 21 | PASS |
| Associated societies / reps | 7 / 7 | 7 / 7 | PASS |
| Small societies / reps | 8 / 8 | 8 / 8 | PASS |
| Total ringers represented, 2025 | 34,936 | 33,109 | **FAIL, +1,827** |

A sample of roughly a dozen values, including all the large year-on-year
movements, was checked by eye against the page image and matched.

### Unresolved: the 2025 membership total

The structural checks all pass exactly, which is good evidence that no rows
were dropped, duplicated or misread. The members total does not reconcile.

Sub-totals for reference: Affiliated 33,245; Associated 1,248; Small 443.
Affiliated alone is closer to the printed 33,109 but still 136 out, so the
discrepancy is not simply a matter of which categories are included.

Three candidate explanations, none yet tested:

1. The printed total is computed on a different basis from "sum of the
   membership column" — for instance excluding some class of society, or
   applying a deduplication.
2. The printed total is carried forward from the 2025 paper, while the 2025
   column in this 2026 paper has since been restated by societies.
3. Transcription errors summing to 1,827 while leaving every other check
   intact. Least likely, but not excluded.

**This must be resolved with whoever compiles the Council's membership return
before these figures are used as a denominator or a comparator.** It is not a
matter of tidiness: if "ringers represented" is defined differently from "sum
of membership figures", that definition belongs in the census methodology
before any census estimate is compared against it.

Large year-on-year falls, worth confirming as real rather than assumed:
Devon Association 600 → 143 (−76%), Veronese Association 300 → 64 (−79%),
Dorset County Association 177 → 62 (−65%), Cambridge University 225 → 160
(−29%).

## Known limitations

- **`society` is not a join key.** The names here are ACM display names and do
  not match Dove's affiliation strings — Dove writes "Bath and Wells Diocesan
  Association" where the paper writes "Bath & Wells Diocesan", and "Salisbury
  Diocesan Guild" against "Salisbury Guild". A separate hand-checked crosswalk
  is required; it does not belong in this file, which is a faithful record of
  a published table.
- **Membership is not a person count.** A ringer may belong to several
  societies, so these figures sum memberships, not people.
- **No territorial flag.** ASCY, the Royal Cumberland, the Ladies Guild and
  the university societies are non-territorial and cut across geography. The
  distinction matters for association-level reporting and will be carried in
  the crosswalk, not here.
- **Wide format.** Kept deliberately simple for now. Adding a further year
  means adding columns rather than rows; if more years are ever wanted, this
  should become a long-format table keyed on society and year.

## Provenance of this file

- Source CSV: `cccbr_society_membership_2026.csv`, transcribed by Gemini.
- Renamed and written to `data/reference/` on 2026-09-19.
- Values unchanged from the transcription. Verification above performed on the
  same date. The 2025 total discrepancy remains open.

## Committee notes, 2026-09-20 (see D-023)

- **Devon Association** — the published figure is a count of towers, not
  members. Most likely the 2026 figure (143): Dove lists 163 rings affiliated to
  the association, consistent with a tower count. To confirm which column.
- **Veronese Association** — rings in the Veronese tradition, not change
  ringing. Exclude from change-ringing membership comparisons.

Values in the CSV are unchanged. Neither note explains the 2025 total
discrepancy above, which remains open (Q-003).
