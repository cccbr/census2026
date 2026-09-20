# Working decision register

Current state, at a glance. The reasoning lives in `decisions.md`, which is
append-only; this file is maintained by hand and shows where things stand
now.

**Last reviewed: 2026-09-19 (late evening)**

Statuses: **Provisional** (Mark's working decision, not team-agreed) ·
**Agreed** (ratified by the project team) · **Open** (not decided) ·
**Superseded**.

---

## Decided

| ID | Decision | Status | Agreed by |
| --- | --- | --- | --- |
| D-001 | Frame source is `dove.csv`; chimes and carillons excluded by that choice | Provisional | — |
| D-002 | Unringable (`u/r`) rings excluded from the frame | Provisional | — |
| D-003 | Lightweight rings excluded; subsumes the "no DoveID" rule | Provisional | — |
| D-005 | International rings retained **in the frame**; treatment in chasing and reweighting deferred | Provisional | — |
| D-006 | Frame membership carried as flags (`frame_full`, `frame_1988`, `frame_picklist`), not as a filter | Provisional | — |
| D-007 | `RingID` is the frame key and is what the survey captures | Provisional | — |
| D-008 | Picklist = frame exactly, plus a free-text "not listed" escape | Provisional | — |
| D-009 | Dove's dedication abbreviations shown verbatim, not expanded | Provisional | — |
| D-011 | Society membership recorded as published, uncorrected | Provisional | — |
| D-012 | Picklist is one entry per ring, not per tower; the 13 two-ring towers appear twice | Provisional | — |
| D-013 | Questionnaire captures composite `Display [RingID]` in one field | Provisional | — |
| D-014 | QuestionPro Research tier funded and purchased | **Agreed** | CCCBR |
| D-015 | Tower list fetched from an external host, not embedded in the questionnaire | Provisional | — |
| D-016 | Tower list served as plain text and parsed as data, never as executable JavaScript | Provisional | — |

**D-014 is the only Agreed entry.** Every frame decision is still one person's
working call.

## Current frame counts

On the `dove_2026-09-19` snapshot:

| Rule | Rings |
| --- | --- |
| All rows in `dove.csv` | 7,262 |
| Ringable | 6,297 |
| Ringable + full-circle — **`frame_full`** = **`frame_picklist`** | **6,161** |
| …of which ≥4 bells | 5,775 |
| …of which ≥5 bells | 5,619 |
| …of which British Isles | 6,013 |
| Ringable + full-circle + ≥5 bells + British Isles — **`frame_1988`** | **5,473** |

1988's own frame was 5,425 towers. The 0.9% gap is the best available
evidence that the 1988 rule has been correctly reconstructed.

**Display strings are unique across the picklist — zero collisions.** Better
than the two predicted: the Farnham pair that bell count could not separate
(a ring of ten and a 30lb mini ten) is resolved because D-003 removes the mini
ten.

Hosted payload is 304 KB on disk, ~80 KB gzipped in transit. The widget is
14 KB, inside QuestionPro's JavaScript Logic limit of 16,384–32,768
characters.

---

## Open — needed before the questionnaire ships

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| D-004 | Minimum bell count for `frame_full` | Frame build, picklist | 1988 used ≥5. Mark inclined to include 4s. 386 threes, 156 fours. D-006 makes this less binding than it looks |
| D-010 | Ring or tower as the respondent's unit; the 13 two-ring towers | Analysis, deduplication | D-012 defers it for the picklist; it still has to be answered for analysis |
| Q-001 | Dove CC BY-SA attribution placed in the QuestionPro about/privacy text | Questionnaire build | Wording is `DOVE_ATTRIBUTION` in `scripts/00_setup.R` |
| Q-002 | Widget validation tests | Questionnaire build | **Test 3 (payload size) resolved by D-015 — superseded.** Still outstanding: value capture verified from submitted response data; mobile on real devices; back-navigation |
| Q-014 | **Where the tower list is hosted for fieldwork** | Questionnaire build, DPIA | `raw.githubusercontent.com` is the test host only — GitHub rate-limits it and does not support it as a hosting endpoint. Candidates: CCCBR infrastructure (needs one CORS header) or jsDelivr pinned to a tag. Mark meeting CCCBR 2026-09-20 |
| Q-015 | Does the network dependency need naming in the DPIA and privacy notice? | Publication, DPIA | The questionnaire now makes an outbound request to a third-party host while a respondent completes it |
| Q-011 | Does QuestionPro re-run Pre JavaScript Logic on back-navigation? | Widget design | If not, careful respondents who go back get an uncontrolled free-text field. Step 4 in `inst/questionnaire/todo.md` |
| Q-012 | **Date by which the widget-vs-fallback decision must be made** | Everything downstream | Cascading county questions are ~60 lookup questions plus branching. Reverting close to fieldwork would be expensive. **Not yet set — Mark to word this** |
| Q-013 | Ship without keyboard navigation and screen-reader support, or not? | Questionnaire build | A scope decision, not a technical one. Steps 6–7 in the todo list. Respondent population skews older |

## Open — needed before analysis

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| D-005a | Whether international towers enter chasing and reweighting, and if so which countries | Sub-sample design, estimation | 148 rings; 114 in Australia and the USA |
| Q-003 | The 1,827 discrepancy in the 2025 membership total | Any use of society figures as denominator | Needs the Council's membership compiler |
| Q-004 | Whether unringable towers are reported on separately | Reporting scope | 1988 did report on them; D-002 excludes them from the frame, which is not the same thing |
| Q-005 | Source of branch / district attribution | Association reporting | Not in Dove. Associations supply a lookup, or it is collected in the survey |
| Q-006 | Territorial society assignment rule for towers with multiple or no affiliations | Association reporting, script 03 | 169 rings carry 2+ affiliations (semicolon-delimited); **1,057 carry none** |
| Q-007 | Minimum cell size and suppression rules | Association reports | Must be settled in the data layer, not the report layer |

## Open — governance and legal

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| Q-008 | Whether published census outputs are "adapted material" under CC BY-SA 4.0 §4 | Publication | Sui generis database rights. For legal/DP sign-off |
| Q-009 | Independent data protection professional sign-off | Publication, enumerator deployment | Noted as pending |
| Q-010 | Which Provisional decisions must be escalated to Agreed before publication | Publication | Currently all but D-014. D-013 in particular must not survive to fieldwork unexamined |

---

## Escalation

Before anything is published, every Provisional decision that materially
affects a reported number is either taken to the project team for agreement,
or named in the output as provisional with its alternatives stated.

`Q-010` exists so that this cannot be forgotten. It is not closed until the
list above has been worked through.
