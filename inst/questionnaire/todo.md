# Tower autocomplete — work list

Ordered for single-step debugging. One change, pasted, tested, confirmed,
before the next. Debugging inside QuestionPro is slow and gives poor error
feedback, so batching changes makes failures impossible to attribute.

`CFG.debug = true` logs each stage to the console and prints a version stamp
under the search box — use it to confirm which paste is live before concluding
anything about behaviour.

---

## Done

- **Full scale.** The 6,297-ring picker loads, indexes in ~40 ms, and searches
  correctly.
- **Value capture** confirmed from the response backend (was step 1).
- **iPhone 13 Safari** works (part of step 3).
- **Layout** — v4.3 reserves page space for the confirmation box and cannot
  overflow the viewport.
- **Hosting** on GitHub Pages from `docs/` (D-021).
- **Search folding.** `St Mary Amersham` → `Amersham, S Mary V (12) —
  Buckinghamshire`. v2 would have returned nothing.
- **External hosting proven.** fetch and script-tag both permitted; no CSP
  obstacle.
- **Payload size problem resolved** by D-015 — this was validation test 3.

---

## Step 1 — value capture

**The one that matters.** Everything else is usability; this is whether the
census gets data at all.

Select a tower, submit, open Analytics → Raw Data or an export, and confirm the
field contains e.g. `Henley on Thames, S Mary (6) — Oxfordshire [30]`.

**Do not accept the green confirmation as evidence.** It proves the click
handler ran, nothing more.

v4 dispatches both `input` and `change`, which covers more frameworks than
v2's `change` alone. If capture still fails, the standard workaround for
React-controlled inputs is:

```js
var setter = Object.getOwnPropertyDescriptor(
  window.HTMLInputElement.prototype, "value").set;
setter.call(native, item.value);
native.dispatchEvent(new Event("input", { bubbles: true }));
```

## Step 2 — bind to the question explicitly

v4 takes the **first** visible text input wider than 50 px. Correct on a
single-question page, a guess everywhere else. Find the input's `name` or `id`
in the inspector and set:

```js
inputSelector: 'input[name="q_12345"]'
```

Until that is set, do not put another text question on the same page.

## Step 3 — mobile

Real iOS and Android devices, not desktop responsive mode, which does not
reproduce the virtual keyboard's effect on the visual viewport.

Expected problem: `position:fixed` positioned from `getBoundingClientRect()`
while the keyboard resizes the viewport. If it fails, either add
`visualViewport` listeners or switch to a full-screen modal on small screens —
arguably a better mobile pattern regardless.

## Step 4 — back-navigation

Select a tower, go forward a page, come back.

- Widget reappears → QuestionPro re-runs Pre JS on back-navigation. Nothing to
  do.
- Bare text box containing the composite value → respondents careful enough to
  check their answer get an uncontrolled free-text field. The `localStorage`
  cache means no refetch, so re-injection is cheap; the poll needs to keep
  running rather than stopping at first bind.

## Step 5 — "my tower isn't listed"

Required by D-008, not yet built. Proposed: a persistent row at the foot of the
results and an option shown when a search returns nothing, switching to free
text and writing `NOT LISTED: <what they typed>`. One field, and the prefix
makes escapes trivially separable for reconciliation.

## Step 6 — keyboard navigation

Arrow keys, Enter to select, Escape to dismiss. A `selectedIndex` variable and
a `keydown` handler; no framework needed.

A scope decision rather than a technical one (Q-013), but the respondent
population skews older and shipping without it should be a logged choice.

## Step 7 — screen reader support

`role="combobox"` with `aria-expanded`, `aria-controls`,
`aria-activedescendant`; `role="listbox"`/`role="option"` on the dropdown; a
polite live region for result counts. Depends on step 6.

## Step 8 — hidden RingID field

Replace the composite `Display [RingID]` with two fields: display visible,
bare `RingID` hidden. The composite is brittle — any dedication containing
square brackets breaks parsing — and couples the analysis key to the display
format. Needs Vicki to add a hidden question. Deferred while the widget is
still being stabilised (D-013).

## Step 9 — production hardening

- Set `FREEZE_PUBLISHED_LISTS <- TRUE` in `scripts/05` so a live list can
  never change under respondents.
- Retire the test copy on the personal `Ainsworld` account.
- `CFG.debug = false`.
- Confirm the Dove CC BY-SA attribution is live in the survey text (Q-001).
- Regenerate from the final frame snapshot; record the build manifest.
- Confirm the deployed script matches `inst/questionnaire/` in the repository.
- **Test the degraded path deliberately**: point `CFG.dataUrl` at a 404 and
  confirm a usable text box with instructions, not a dead question. This is the
  path a respondent on a bad connection will actually hit.

---

## Standing risk: two normalisers

`foldKey()` in JavaScript and `normalise_search_key()` in `R/text.R` must
behave identically, or index and query disagree about what a tower is called —
surfacing only as "I can't find my tower".

Worth a shared fixture: a small committed CSV of input/expected pairs that both
an R test and a browser console snippet check. Cheap insurance against a silent
divergence.

## Standing check: verify what is deployed

Both the widget and the data file have been silently truncated in transit
during development. Before fieldwork, diff the deployed script against the
repository copy, and confirm the hosted file's header counts match what
`scripts/05` generated.
