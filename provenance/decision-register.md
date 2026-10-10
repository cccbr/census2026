# Working decision register

Current state, at a glance. The reasoning lives in `decisions.md`, which is
append-only; this file is maintained by hand and shows where things stand
now.

**Last reviewed: 2026-09-30** — after the committee meeting of 2026-09-20
(Elva, Vicki, Tina, Mark).

Statuses: **Provisional** (Mark's working decision, not team-agreed) ·
**Agreed** (ratified by the project team) · **Agreed in principle** (endorsed,
details still to settle) · **Open** (not decided) · **Superseded**.

---

## Decided

| ID | Decision | Status |
| --- | --- | --- |
| D-001 | Frame source is `dove.csv`; chimes and carillons excluded by that choice | Provisional |
| D-002 | Unringable (`u/r`) rings excluded from frame and picker | Provisional |
| D-003 | Mini-rings excluded from the **frame** | **Agreed** 2026-09-20 |
| D-006 | Frame membership carried as flags (`frame_full`, `frame_1988`, `frame_picklist`), not filters | Provisional |
| D-007 | `RingID` is the frame key and is what the survey captures | Provisional |
| D-009 | Dove's dedication abbreviations shown verbatim | Provisional |
| D-011 | Society membership recorded as published, uncorrected | Provisional |
| D-012 | Picker is one entry per ring; the 13 two-ring towers appear twice | Provisional |
| D-013 | Questionnaire captures composite `Display [RingID]` in one field | Provisional |
| D-014 | QuestionPro Research tier funded and purchased | **Agreed** — CCCBR |
| D-015 | Tower list fetched from an external host, not embedded | Provisional |
| D-016 | Tower list served as plain text, never as executable JavaScript | Provisional |
| D-017 | Sampling frame is **4+ bells**; 1988 comparison uses `frame_1988` | **Agreed** 2026-09-20 |
| D-018 | Picker is **broader** than the frame: every ringable ring, threes and mini-rings included | **Agreed** 2026-09-20 |
| D-019 | International rings in the frame where a volunteer is present; list in reference CSV | **Agreed in principle** 2026-09-20 |
| D-020 | Mini-rings marked in every display string | Provisional |
| D-021 | Tower list hosted on GitHub Pages from `cccbr/census2026`; committee informed | Provisional |
| D-022 | Dove authoritative for bells, not affiliations; association registers prevail, disagreements logged | **Agreed** as working prior — Vicki, Tina |
| D-023 | Devon and Veronese membership figures not comparable as published | **Agreed** 2026-09-20 |
| D-024 | ~~Tower list always fetched~~ — superseded by D-025 | Superseded |
| D-025 | Tower list checked once per questionnaire (browser tab); stored copy used thereafter. Timeouts 20 s with nothing stored, 3 s with a copy | Provisional |
| D-026 | Settlement measures: exponential kernels (half-distances 1/2/4/8 km, prior mode 2 km) and plain radii (1/2/5/10 km). Huff / competing-destinations allocation considered and deferred | Provisional |

Superseded: D-004 → D-017 · D-005 → D-019 · D-008 → D-018.

## Current frame counts

On the `dove_2026-09-19` snapshot:

| Flag | Rule | Rings |
| --- | --- | --- |
| — | All rows in `dove.csv` | 7,262 |
| **`frame_picklist`** | Every ringable ring (D-018) | **6,297** |
| **`frame_full`** | Ringable, full-circle, 4+ bells, British Isles + volunteer countries (D-017, D-019) | **5,743** |
| | …of which Australia and USA | 114 |
| **`frame_1988`** | Ringable, full-circle, 5+ bells, British Isles — the 1988 rule | **5,473** |

In the picker but outside the frame: **554** — 386 rings of three, 136
mini-rings, 32 international rings in countries without a volunteer.

1988's own frame was 5,425 towers; `frame_1988` is 0.9% from it, which is the
evidence that the rule is correctly reconstructed.

Display strings are unique across all 6,297 picker entries (D-020).

---

## Open — needed before fieldwork

| ID | Question | Notes |
| --- | --- | --- |
| D-010 | Ring or tower as the respondent's unit; the 13 two-ring towers | **Deferred by the committee 2026-09-20.** D-012 handles the picker; analysis still needs an answer |
| Q-001 | Dove CC BY-SA attribution in the QuestionPro about/privacy text | Wording is `DOVE_ATTRIBUTION` in `scripts/00_setup.R` |
| Q-002 | Widget validation | **Value capture: passed** (backend shows `Amersham, S Mary V (12) — Buckinghamshire [4914]`). **iPhone 13 Safari: passed.** Layout fix v4.3 tested desktop and mobile. **Outstanding: back-navigation** (Q-011). Cause of the 19 Sept live-mode failure not recorded — most likely the header-format mismatch |
| Q-011 | Does QuestionPro re-run Pre JS on back-navigation? | If not, a respondent who goes back gets an uncontrolled free-text field |
| Q-012 | **Date by which the widget-vs-fallback decision is final** | Less urgent now the widget works end to end, but still unset |
| Q-013 | Ship without keyboard navigation and screen-reader support? | A scope decision. Respondent population skews older |
| Q-014 | ~~Hosting~~ | **Resolved by D-021.** Remaining work: make repo public, enable Pages from `/docs`, update `CFG.dataUrl`, retire the personal-account test host |
| Q-015 | Does the network dependency need naming in the DPIA and privacy notice? | The committee has been informed (transparency). DPIA coverage still to be confirmed |
| Q-018 | Confirm the volunteer-country list | Currently Australia and USA, marked `expected` in the reference CSV. Needs an owner who maintains it |
| Q-022 | **Special-case towers**: who is on the list, and are they a certainty stratum or handled outside the chased sample? | Draft list (81 rows, all `proposed`) in `data/reference/special_towers_draft.csv`. Needed before the draw |
| Q-023 | **The settlement classification used to stratify the chased sample** | Candidates are explored in `analysis/tower-context.qmd`: GHSL Degree of Urbanisation, k-means clusters, a two-scale grid. Needed before the draw. Analytical team to calibrate and name |

## Open — needed before analysis

| ID | Question | Notes |
| --- | --- | --- |
| Q-003 | The 1,827 discrepancy in the 2025 membership total | Not explained by D-023, which concerns the 2026 column |
| Q-004 | Whether unringable towers are reported on separately | 1988 did report on them |
| Q-005 | Source of branch / district attribution | Not in Dove |
| Q-006 | Territorial society assignment for towers with multiple or no affiliations | 169 rings with 2+ affiliations; 1,057 with none. D-022 governs conflicts |
| Q-007 | Minimum cell size and suppression rules | In the data layer, not the report layer |
| Q-017 | **What happens to responses from rings outside the frame?** | A consequence of D-018. Such responses have no denominator, so cannot enter the weighted estimate. Proposal: retain and report descriptively, excluded from estimation. Needs deciding before the first one arrives |

| Q-020 | Bells at a tower with two frame rings: max or sum | Affects Gresford and Rugby only, on `dove_2026-09-19`. Code uses max |
| Q-021 | GHSL population epoch | E2020 in use. JRC describes 2025 and 2030 as "projections to 2025 and 2030 derived from CIESIN GPWv4.11" |

## Open — operations

| ID | Question | Notes |
| --- | --- | --- |
| Q-016 | **Enumerator status via Google Sheets** | Agreed in principle 2026-09-20; not yet tested technically. To establish: whether the QuestionPro tier exposes response status via API or only manual export; that the sheet shows per-tower completion status and nothing identifying a respondent; that disclosure to enumerators is covered in the DPIA |

## Open — governance and legal

| ID | Question | Notes |
| --- | --- | --- |
| Q-008 | Are published outputs "adapted material" under CC BY-SA 4.0 §4? | For legal/DP sign-off |
| Q-009 | Independent data protection professional sign-off | Pending |
| Q-010 | Which Provisional decisions must be escalated before publication | Now fewer: the frame decisions are Agreed. D-013 still must not reach fieldwork unexamined |

---

## Escalation

Before anything is published, every Provisional decision that materially
affects a reported number is either taken to the project team for agreement, or
named in the output as provisional with its alternatives stated.

The 2026-09-20 meeting was the first use of this: D-003, D-017, D-018, D-019
and D-023 moved to Agreed.
