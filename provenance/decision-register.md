# Working decision register

Current state, at a glance. The reasoning lives in `decisions.md`, which is
append-only; this file is maintained by hand and shows where things stand
now.

**Last reviewed: 2026-09-19**

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

**Nothing in this register is yet Agreed.** Every frame decision is currently
one person's working call.

## Current frame counts

On the `dove_2026-09-19` snapshot:

| Rule | Rings |
| --- | --- |
| All rows in `dove.csv` | 7,262 |
| Ringable | 6,297 |
| Ringable + full-circle — **`frame_full`** | **6,161** |
| …of which ≥4 bells | 5,775 |
| …of which ≥5 bells | 5,619 |
| …of which British Isles | 6,013 |
| Ringable + full-circle + ≥5 bells + British Isles — **`frame_1988`** | **5,473** |

1988's own frame was 5,425 towers. The 0.9% gap is the best available
evidence that the 1988 rule has been correctly reconstructed.

---

## Open — needed before the questionnaire ships

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| D-004 | Minimum bell count for `frame_full` | Frame build, picklist | 1988 used ≥5. Mark inclined to include 4s. 386 threes, 156 fours. D-006 makes this less binding than it looks |
| D-010 | Ring or tower as the respondent's unit; the 13 two-ring towers | Picklist | To be decided by hand, 13 rows |
| Q-001 | Dove attribution wording placed in the QuestionPro about/privacy text | Questionnaire build | CC BY-SA 4.0 requires it; wording is in `scripts/00_setup.R` |
| Q-002 | The three outstanding QuestionPro widget validation tests | Questionnaire build | Value capture in response data; mobile; full-payload acceptance |

## Open — needed before analysis

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| D-005a | Whether international towers enter chasing and reweighting, and if so which countries | Sub-sample design, estimation | 148 rings; 114 in Australia and the USA |
| Q-003 | The 1,827 discrepancy in the 2025 membership total | Any use of society figures as denominator | Needs the Council's membership compiler |
| Q-004 | Whether unringable towers are reported on separately | Reporting scope | 1988 did report on them; D-002 excludes them from the frame, which is not the same thing |
| Q-005 | Source of branch / district attribution | Association reporting | Not in Dove. Associations supply a lookup, or it is collected in the survey |
| Q-006 | Territorial society assignment rule for towers with multiple or no affiliations | Association reporting | 169 rings carry 2+ affiliations (semicolon-delimited); **1,057 carry none** |
| Q-007 | Minimum cell size and suppression rules | Association reports | Must be settled in the data layer, not the report layer |

## Open — governance and legal

| ID | Question | Blocks | Notes |
| --- | --- | --- | --- |
| Q-008 | Whether published census outputs are "adapted material" under CC BY-SA 4.0 §4 | Publication | Sui generis database rights. For legal/DP sign-off |
| Q-009 | Independent data protection professional sign-off | Publication, enumerator deployment | Noted as pending |
| Q-010 | Which Provisional decisions must be escalated to Agreed before publication | Publication | Currently that is all of them |

---

## Escalation

Before anything is published, every Provisional decision that materially
affects a reported number is either taken to the project team for agreement,
or named in the output as provisional with its alternatives stated.

`Q-010` exists so that this cannot be forgotten. It is not closed until the
list above has been worked through.
