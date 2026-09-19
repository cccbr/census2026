# Decision log

Append-only. Chronological record of analytical and data-structure decisions
for the 2026 Ringing Census, with the considerations behind them.

**Entries are never edited or deleted.** A decision that changes gets a new
entry; the old one is marked `Superseded` with a pointer. This file is the
history. `decision-register.md` is the current-state view.

Tooling and repository conventions live in `CLAUDE.md`, not here. This file is
for decisions that affect what the numbers mean.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| **Provisional** | A working decision taken by Mark to allow progress. Not agreed by the project team. Reversible, and expected to be revisited. |
| **Agreed** | Ratified by the project team. The entry names who agreed and when. |
| **Open** | Identified as needing a decision. Not decided. |
| **Superseded** | Replaced by a later entry, which is named. |

**The rule that matters:** a `Provisional` decision must not reach a published
output silently. Before publication it is either escalated to `Agreed`, or the
output states in its own words that the choice was provisional and what the
alternatives were. Provisional decisions quietly becoming permanent is the
failure mode this file exists to prevent.

## Referencing

Each decision has an ID (`D-001`). Cite it in code at the point the decision
is encoded:

```r
filter(ring_type == "Full-circle ring")   # D-003
```

Anyone reading the code can then find out why, and anyone reading the register
can find where it bites.

---

## D-001 — Sampling frame source is `dove.csv`, not `towers.csv`

**2026-09-19 · Provisional (Mark)**

The frame is drawn from Dove's `dove.csv` (7,262 rows, full-circle and
lightweight rings) rather than `towers.csv` (15,720 rows, all bell
collections).

**Effect:** chimes and carillons are excluded. `RingType` in `dove.csv` takes
only two values — `Full-circle ring` and `Lightweight ring` — so this file
choice already implements the "chimes out" intent; no separate filter is
needed.

**Reasoning:** a chime is not hung for full-circle ringing, so change ringing
by a band is not possible at one. This is definitional rather than a matter of
community opinion.

**Alternatives:** use `towers.csv` and filter. Rejected as more work for the
same result, and it would put 8,000+ irrelevant rows in front of respondents.

---

## D-002 — Unringable rings are excluded from the frame

**2026-09-19 · Provisional (Mark)**

Rings where Dove's `UR` field holds `u/r` are excluded. 965 of 7,262.

**Reasoning:** a ring that cannot be rung cannot have had ringing in the
reference week. Including them would put a large block of structural zeros
into the estimation.

**Open sub-question:** 1988 surveyed unringable towers and reported on them
(*"of the 31 unringable towers, one-third occur in each of two regions"*), and
the incumbent instrument specifically covered ringable-but-unrung bells.
Excluding them from the **frame** is not the same as declining to **count**
them. Whether the census should report an unringable-tower figure alongside the
population estimate is not settled here — see `Q-004` in the register.

---

## D-003 — Lightweight rings are excluded from the frame

**2026-09-19 · Provisional (Mark)**

`RingType == "Lightweight ring"` is excluded. 138 rows, of which 136 ringable.

**Reasoning:** mini-rings are typically private, in a garden or outbuilding,
and rarely have anything resembling a tower representative. Their regular
ringers are in most cases counted at their home towers, so including them
risks double-counting — the same problem as itinerant ringers, in a form that
is harder to detect.

**Mark's stated condition:** exclude *"unless it's genuinely likely that it's
the basis of a recurrent band that doesn't ring anywhere else."* That condition
is not testable from Dove alone. Not tested; noted as a limitation.

**Finding that simplifies this:** the separate proposal to exclude rings
lacking a `DoveID` turns out not to be an independent criterion. All 118 rings
with a blank `DoveID` are lightweight rings, and **every** ringable
full-circle ring has both a `DoveID` and a `TowerBase` value. So "no DoveID"
and "lightweight" select the same rows, and only D-003 is needed. 112 of the
118 also carry no affiliation, which is consistent with the private-mini-ring
reading.

**Resulting frame: 6,161 ringable full-circle rings.**

---

## D-004 — Minimum bell count

**2026-09-19 · OPEN**

Not decided. Mark is inclined to include rings of four, on the grounds that
plain hunt on four is real ringing.

**Evidence from 1988 — this cuts against that inclination.** The 1988 survey's
frame was explicitly five or more bells in the British Isles: *"there are some
5425 towers with five or more bells in the British Isles according to Ron
Dove's latest Guide"*, and the conclusions are framed the same way — *"If a
third or more of British Isles' church towers with rings of five or more bells
are silent..."*

Applying the 1988 rule to the 2026-09-19 Dove snapshot gives **5,473** against
1988's 5,425 — 0.9% apart after thirty-eight years, which is good evidence the
rule has been reconstructed correctly.

**Counts at stake:** 386 rings of three, 156 rings of four.

**The resolution this points to** is not to choose between the two, but to
carry both — see `D-006`.

---

## D-005 — Geographic scope

**2026-09-19 · Provisional (Mark)**

International rings are retained in the frame. 148 ringable full-circle rings
lie outside the British Isles, of which 114 are in Australia or the USA.

**Reasoning:** the census scope is "Britain and beyond", and excluding them at
frame level would make it impossible to report on them at all.

**Explicitly deferred:** whether international towers enter the chased
sub-sample, and whether they are included in the reweighted population
estimate. Mark's view is that they may be excluded from chasing and
reweighting entirely, or restricted to the larger countries. Not decided.

**Note for comparability:** 1988 was British Isles only, so any 1988
comparison must use the British Isles subset regardless of what the full frame
contains.

---

## D-006 — Frame membership is carried as flags, not as a filter

**2026-09-19 · Provisional (proposed by Claude, adopted by Mark — pending)**

The curated frame table holds one row per ring with boolean columns for each
frame definition, rather than being filtered down to a single frame:

- `frame_full` — ringable, full-circle (6,161)
- `frame_1988` — ringable, full-circle, ≥5 bells, British Isles (5,473)
- `frame_picklist` — what appears in the questionnaire dropdown

**Reasoning:** the census has two objectives that want different denominators.
The 1988 comparison needs 1988's frame; a current picture of ringing wants the
widest defensible one. Filtering to one frame forces a choice that does not
need making, and makes the other analysis impossible without rebuilding.

It also dissolves `D-004`: rings of three and four can be in `frame_full` and
out of `frame_1988` without either decision being wrong.

**Trade-off:** every downstream analysis must state which flag it uses. That
is a discipline cost, but it is the same discipline as naming the snapshot,
and it makes the denominator explicit in the code rather than implicit in a
filter several scripts upstream.

---

## D-007 — The frame key is `RingID`

**2026-09-19 · Provisional (Mark)**

`RingID` is the primary key and is what the survey captures.

**Reasoning:** `RingID` is unique across all 7,262 rows. `TowerID` is not — 13
towers hold two rings each. `DoveID` is blank for 118 rings. Tower *names* are
neither unique nor stable.

**Supersedes** the earlier note in `CLAUDE.md` that the survey should capture
the Dove ID, which was wrong on both counts.

---

## D-008 — Questionnaire picklist equals the frame, plus an escape hatch

**2026-09-19 · Provisional (Mark)**

The dropdown offers exactly the frame, plus an explicit "my tower isn't
listed" option capturing free text.

**Reasoning:** inflating the picklist beyond the frame creates responses with
no denominator; restricting it below the frame leaves respondents stuck. The
free-text escapes become a small, auditable reconciliation task rather than a
silent data-quality problem.

---

## D-009 — Dove's dedication abbreviations are shown verbatim

**2026-09-19 · Provisional (Mark)**

Display strings carry Dove's own abbreviations — `S Mary V`, `S Edmund K&M`,
`Cath Ch of S Machar` — rather than expanding them.

**Reasoning:** ringers are familiar with them. Expanding needs a curated
abbreviation map, and a mis-expansion would be a defect in the one field that
must be right. The search key folds `S`/`St`/`Saint` regardless, so typing
either form finds the tower.

---

## D-010 — Two-ring towers

**2026-09-19 · OPEN**

Thirteen towers hold two rings each. Whether a respondent identifies a ring or
a tower is not decided, and the right answer differs case by case: Gresford's
eight and six are one band; South Stoneham's parish three and the Southampton
University campanile are almost certainly not.

**Approach proposed:** decide all thirteen by hand and commit the result as a
reference table. Thirteen rows is a curated list, not an algorithm.

---

## D-011 — Society membership figures are recorded as published

**2026-09-19 · Provisional (Mark)**

`data/reference/cccbr_society_membership_2025-2026_acm2026-p58.csv` is a
faithful record of the ACM paper's table. No values corrected, no join keys
added.

**Unresolved and material:** the transcribed 2025 membership total is 34,936
against the paper's printed 33,109 — a difference of 1,827 — while every
structural check (society counts, reps, vacancies) reconciles exactly. See the
accompanying `.md` for the three candidate explanations. **This must be
settled with whoever compiles the Council's return before the figures are used
as a denominator or comparator.**

---

## D-012 — Picklist entries are one per ring, not one per tower

**2026-09-19 · Provisional (Mark)**

The questionnaire picklist carries one entry per `RingID`. The 13 towers
holding two rings therefore appear twice.

**Reasoning:** `RingID` is the key (D-007), and bell count in the display
string distinguishes the pairs. Deciding the 13 properly requires case-by-case
judgement — Gresford's eight and six are one band; South Stoneham's parish
three and the Southampton University campanile are almost certainly not — and
that judgement should not block the payload.

**Supersedes nothing. Leaves D-010 open.**

**Finding:** with lightweight rings excluded (D-003), the picklist has **zero**
colliding display strings — better than the two predicted. The Farnham pair
that could not be separated by bell count (a ring of ten and a 30lb mini ten,
both showing as 10) is resolved because the mini ten is a lightweight ring and
D-003 removes it. One exclusion rule quietly solved a display-uniqueness
problem.

---

## D-013 — The questionnaire captures a composite `Display [RingID]` string

**2026-09-19 · Provisional (Mark)**

The widget writes `"<display> [<RingID>]"` into a single QuestionPro text
field, rather than a bare RingID or a separate hidden field.

**Reasoning:** it needs no QuestionPro-side change and is what already works,
which matters while the widget itself is being stabilised. Debugging inside
QuestionPro is slow and gives poor error feedback, so moving parts are added
one at a time.

**Known cost, accepted for now:** the value is brittle — any dedication
containing square brackets breaks parsing — and it couples the analysis key to
the display format, so changing a label silently changes the data. The
production answer is a hidden RingID field; that is step 8 in
`inst/questionnaire/todo.md`.

**This must not survive to fieldwork unexamined.** See Q-010.

---

## D-014 — QuestionPro Research tier is funded and locked in

**2026-09-19 · Agreed (CCCBR)**

JavaScript Logic requires Team or Research edition; the Non-Profit Waiver maps
to Advanced, which does not have it. The CCCBR has approved official purchase
of Research tier and funding was approved at full price, so the dependency is
resolved rather than merely noted.

**Residual note:** the quoted price is believed to be lower than it should be
owing to a misunderstanding on the vendor's side. Funding exists for the full
price, so a corrected invoice is not a risk to the project — but a licence
that lapses mid-fieldwork would silently break the tower question, so the
renewal date is worth knowing.
