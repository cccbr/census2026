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
| **Agreed in principle** | Endorsed by the team with named details still to settle. Treated as Agreed for design work; not for publication until the details are settled. |
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

**2026-09-19 · Provisional (Mark) → Agreed for the frame 2026-09-20 (committee) · picker inclusion: see D-018**

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

**2026-09-19 · OPEN → Superseded by D-017**

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

**2026-09-19 · Provisional (Mark) → Superseded by D-019**

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

**2026-09-19 · Provisional (Mark) → Superseded by D-018** (the escape hatch itself stands)

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

**2026-09-19 · OPEN · deferred by the committee 2026-09-20**

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

---

## D-015 — The tower list is fetched from an external host, not embedded

**2026-09-19 · Provisional (Mark) · proven working end to end**

The questionnaire fetches the tower list from a URL at runtime. It is not
embedded in the survey.

**Why there was no alternative.** QuestionPro's limits were established
empirically, by pasting padded scripts of known size:

| Field | Limit |
| --- | --- |
| JavaScript Logic | between 16,384 and 32,768 characters (16k passed, 32k failed) |
| Rich-text content block | 10,000 characters, counting injected markup |

The frame is 6,161 rings. Encodings measured against it: plain `id|display|alt`
304 KB; dictionary-encoding dedication and county 166 KB; adding prefix-coding
of the sorted place column 144 KB; gzip+base64 88 KB. Against a payload budget
of roughly 19 KB after template overhead, the smallest of these is still seven
times too large. **No encoding closes that gap**, and the exercise is what
established it rather than assuming it.

A request to raise the platform limit was made and refused.

Chunking across ten hidden content blocks was prototyped and verified working
(reassembly by regex, gunzip, checksum match). It was rejected: ten pastes
repeated on every data refresh, six failure points, and debuggable by nobody
except the two people who built it.

**Proven, not assumed.** Two probes run in QuestionPro preview established
that outbound requests are permitted: `fetch` returned HTTP 200 in 61 ms with
no CSP violation, and a `<script>` tag loaded in 63 ms. The full widget was
then tested end to end against a file on `raw.githubusercontent.com` — 6,161
rings indexed, and "St Mary Amersham" correctly matched "Amersham, S Mary V
(12) — Buckinghamshire".

**Accepted risk.** The questionnaire now depends on a network fetch during the
reference week. A respondent behind a restrictive proxy, or on a poor
connection, will not get the picker.

**Mitigations, all implemented:** an 8-second timeout; `localStorage` caching
keyed by snapshot, so a returning or back-navigating respondent does not
refetch; and a degraded path that restores a plain text box with instructions
("type your tower's place name and dedication") rather than leaving a dead
question. Degraded responses are separable at analysis time and join the
free-text reconciliation task.

**Open:** where it is hosted. `raw.githubusercontent.com` is the test host and
is not suitable for fieldwork — GitHub rate-limits it and does not support it
as a hosting endpoint. Production candidates are CCCBR's own infrastructure
(politically correct, they already run Dove) or jsDelivr pinned to a git tag
(immutable URL, proper CDN). See Q-014.

---

## D-016 — The tower list is served as plain text, not as JavaScript

**2026-09-19 · Provisional (Mark)**

The hosted file is `towers_<snapshot_id>.txt`, fetched with `fetch()` and
parsed as data.

**Reasoning — this is a security decision, not a stylistic one.** The first
implementation served a `.js` file assigning a global, loaded by a `<script>`
tag. That requires no CORS headers from the host, which is operationally
convenient. It also means the questionnaire **executes remote code in the
respondent's browser**: if the host were ever compromised, arbitrary
JavaScript would run on a page collecting census responses. Fetched as data,
the worst case is bad data, which the header counts catch.

Host convenience is not worth that trade for a project with a DPIA in flight.

**Secondary benefits:** the file is readable with `curl`, greppable, and
usable by anything that is not this widget — an association officer checking
their towers are listed, or Bryn working in Python. A JSON blob or a `.js`
assignment would be none of those things, and the provenance chain is about
data.

**Cost:** `fetch` requires `Access-Control-Allow-Origin` from the host, which
a script tag would not have. `raw.githubusercontent.com` and jsDelivr both
send it. Self-hosting on CCCBR infrastructure needs one line of server
configuration — which must be confirmed before it is promised, not discovered
during fieldwork.

**Format.** First line `# <snapshot_id> <n_rings> <n_chars>`, then one row per
ring as `RingID|display|alt names`.

Integrity is carried as counts rather than a checksum. Counts catch the
realistic failures — truncation and a partial cache write. Corruption in
transit is prevented by HTTPS; the wrong file is caught by the snapshot id;
and a hash cannot detect tampering, because whoever can alter the file can
alter the header. A 32-bit hash would also have to be reimplemented
identically in R, which has no native unsigned 32-bit arithmetic — exactly the
silent cross-language divergence already being managed with the search-key
normaliser.

---

## D-017 — The sampling frame is rings of four or more bells

**2026-09-20 · Agreed — committee (Elva, Vicki, Tina, Mark)** · supersedes D-004

The sampling frame includes full-circle rings of four or more bells.

**This departs from 1988**, whose frame was five or more: *"some 5425 towers
with five or more bells in the British Isles"*. Comparability is preserved by
the `frame_1988` flag (D-006), which still reconstructs the 1988 rule — 5,473
rings on the 2026-09-19 snapshot. **Any 1988 comparison uses `frame_1988`, not
`frame_full`.**

**Reasoning:** plain hunt on four is real change ringing, and a ring of four can
sustain a band.

**Frame on `dove_2026-09-19`, with D-019: 5,743 rings.**

---

## D-018 — The picker is broader than the sampling frame

**2026-09-20 · Agreed — committee (Elva, Vicki, Tina, Mark)** · supersedes D-008

The questionnaire picker offers **every ringable ring**: full-circle rings of
any bell count, and mini-rings. **6,297 rings.** The sampling frame remains as
set by D-017 and D-019.

**Reasoning:** some mini-rings are the location of regular practices, though
most are not, and rings of three can have bands. Nobody who rings somewhere real
should be forced into the free-text escape to name it. The escape remains, for
rings absent from Dove altogether.

Mini-rings stay out of the *frame* (D-003) because most do not host a band that
rings nowhere else — including them would add structural zeros and
double-counting risk to the estimate.

**Consequence:** responses will arrive from rings outside the frame — a ring of
three, a mini-ring, a tower in a country without a volunteer. See Q-017.

**Implementation:** `frame_picklist = is_ringable` in `R/frame.R`. Frame and
picker are flags on one table (D-006), which is why this split cost one line.

---

## D-019 — International rings are in the frame where a volunteer is present

**2026-09-20 · Agreed in principle — committee (Elva, Vicki, Tina, Mark)** · supersedes D-005

Rings outside the British Isles enter the sampling frame for countries where a
CCCBR volunteer is present.

**Reasoning (committee):** in practice these will be quirky, but the census is
about engaging ringers everywhere, not only in the British Isles.

**The list lives in `data/reference/frame_countries_with_volunteers.csv`**,
read by `scripts/04_build_frame.R` — never hard-coded. It currently holds
Australia and the United States of America, marked `expected`: the list is still
to be confirmed (Q-018). That is why this is Agreed *in principle*.

On `dove_2026-09-19` the two countries contribute **114 rings** to the frame.
The remaining **32** international rings of four or more bells appear in the
picker only.

Rings in volunteer countries are part of the population being estimated.
Whether any are allocated to the chased sub-sample is a sub-sample design
question, not settled here.

---

## D-020 — Mini-rings are marked in every display string

**2026-09-30 · Provisional (Mark)**

Every mini-ring's display carries the marker, for example
`Abbots Bromley, The Campanile (8, mini-ring) — Staffordshire`. Applied
universally, not only where two rings would otherwise collide.

**Reasoning:** a respondent should never mistake a mini-ring for the full-circle
ring in the same place. It also resolves the collision that D-018 would
otherwise reintroduce — Farnham S Andrew's ring of ten and its 30lb mini ten
both displayed as `(10)`. **Zero collisions across all 6,297 picker entries.**

---

## D-021 — The tower list is hosted on GitHub Pages from `cccbr/census2026`

**2026-09-30 · Provisional (Mark) · committee informed** · resolves Q-014

Suggested by Graham John on 2026-09-29. It is the pattern already used by six
Council sites: `methods`, `framework`, `callingitround`, `callchanges`,
`belfryupkeep` and `belfryprojects` `.cccbr.org.uk`.

**Verified:** a `fetch()` from a QuestionPro page to `methods.cccbr.org.uk`
returned HTTP 200 — CCCBR's Pages sites send the CORS headers that D-016
requires.

**Planned mechanics:** publish from a `/docs` folder on `main` rather than a
separate `gh-pages` branch, so the served file sits in the same history as the
code that generated it. `inst/questionnaire/build/` stays gitignored as
regenerable scratch; `docs/` holds exactly what respondents receive. Versioning
is by filename (`towers_<snapshot>.txt`), because Pages serves only the latest
commit.

**Requires the repository to be public.** Supersedes the test host
(`raw.githubusercontent.com/Ainsworld/cccbr_census2026`), which should be
retired once the Pages URL is live so nothing points at a personal account.

The committee has been told the list is hosted externally. That is transparency,
not DPIA coverage — **Q-015 still stands.**

---

## D-022 — Dove is authoritative for bells, not for affiliations

**2026-09-20 · Agreed as a working prior — Vicki, Tina**

Dove's information about which association a tower belongs to is likely to be
less accurate than its information about the bells themselves. Where an
association's own register or website disagrees with Dove, **the association's
source prevails, and every disagreement is logged** rather than silently
resolved.

Shapes `scripts/03` (the society crosswalk, not yet written) and Q-006.

---

## D-023 — Two published society membership figures are not comparable

**2026-09-20 · Agreed — committee (Elva, Vicki, Tina, Mark)** · annotates D-011

- **Devon Association:** the published figure is a count of towers, not members,
  because of how the association keeps its records. Which column is affected was
  not minuted. The 2026 figure (143) is the likely one: Dove lists **163 rings**
  affiliated to the Devon Association, consistent with a tower count, whereas
  600 is not. **To confirm.**
- **Veronese Association:** rings in the Veronese tradition, not change ringing.
  Exclude it from any change-ringing membership comparison. Dove holds no
  Italian rings, so there is no effect on the frame.

The CSV is unchanged: it remains a faithful record of the published table
(D-011). These are interpretive notes for anyone using it.

**Neither explains Q-003.** The 1,827 discrepancy is in the *2025* column, and
remains open.

---

## D-024 — The tower list is always fetched; the local copy is a fallback only

**2026-09-30 · Provisional (Mark)** · corrects the caching described in D-015

Every page load fetches the list with `cache: "no-cache"`, so the browser
revalidates with GitHub Pages each time: a "not modified" reply when the list is
unchanged, the new list when it has been republished. The copy kept in
`localStorage` is used **only** when the network fails or returns a file whose
header counts do not match.

**Reasoning:** no tester, volunteer or respondent should ever need to know a
cache exists. Up to v4.3 the widget consulted its cache *first*, under a single
fixed key, and never checked the server while that copy was intact. When the
list was republished at the same URL (6,161 → 6,297 rings under D-018), testers
kept seeing the old list until they cleared browser storage by hand. That is not
an instruction that can be given to volunteers, and a design that depends on it
is wrong.

**Mechanics (v4.4):** the local copy is keyed by URL, and each successful load
deletes every other cached list — including the old fixed-key copy — so anyone
who tested an earlier version recovers automatically. Verified by simulation:
stale old-key copy with network up; network down with a local copy; network down
with none; and a truncated file served with a good local copy.

**Relationship to the freeze.** `FREEZE_PUBLISHED_LISTS` in `scripts/05` still
guarantees a live URL never changes content during fieldwork. Correctness no
longer depends on it; it remains good practice.

D-015's description of the cache as "keyed by snapshot" was never accurate. It is
left as written, per the append-only rule; this entry supersedes it.

---

## D-025 — The tower list is checked once per questionnaire

**2026-09-30 · Provisional (Mark)** · supersedes D-024

The first picker in a browser tab fetches the list with revalidation. Every
later picker in the same tab uses the stored copy **with no network request**.
The "session" is the browser tab (`sessionStorage`): it survives QuestionPro's
page changes and ends when the tab closes.

**Reasoning (Mark's challenge to D-024):** the individual survey shows the
picker several times, and many towers are rural with poor signal. D-024 made a
network round trip at *every* picker. The bytes were trivial — a "not modified"
reply — but the **latency** was not, and on a flaky connection each picker could
wait out the full timeout before falling back.

**Why per-questionnaire rather than a fixed expiry (e.g. 10 minutes):** a
questionnaire can outlast any fixed window, so an expiry would force a refetch
mid-questionnaire — for exactly the slow rural respondent the change is meant
to protect.

**Timeouts now depend on what failure costs:**

| Situation | Timeout | Why |
| --- | --- | --- |
| Nothing stored | 20 s | The alternative is free text, which is worse data than a slow picker. ~80 KB can exceed 8 s on weak 2G/EDGE |
| Stored copy available | 3 s | The alternative is nearly as good |

**Behaviour on failure:** if the stored copy is used because the network
failed, the tab is still marked as checked, so a failing connection costs the
respondent one wait rather than one at every picker. If nothing is stored and
the fetch fails, the tab is *not* marked, so the next picker tries again.

**Still true from D-024:** nobody is ever asked to clear anything. Stored copies
are keyed by URL, and each successful load deletes every other stored list. A
tester who republishes the list opens the survey in a new tab.

**Considered and rejected:** relying on the browser's own HTTP cache, which with
GitHub Pages' headers would give roughly a 10-minute expiry for free. Rejected
because it can be evicted without warning and behaves differently in private
browsing; session storage has predictable, documentable semantics.

**Verified by simulation** across eight cases, including three pickers in one
questionnaire (one network request in total), a hanging connection with a
stored copy (one 3-second wait, then none), and recovery for anyone holding the
pre-v4.4 fixed-key copy.
