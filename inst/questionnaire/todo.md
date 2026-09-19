# Tower autocomplete — work list

Ordered for single-step debugging. Each item is meant to be one change, pasted
into QuestionPro, tested, and confirmed before the next. Debugging inside
QuestionPro is slow and gives poor error feedback, so batching changes makes
failures hard to attribute.

`CONFIG.debug = true` in v3 logs each stage to the browser console and prints
a version stamp under the search box — use it to confirm which paste is live
before concluding anything about behaviour.

---

## Step 0 — viability at full size

**Done in v3.** The generated script carries all 6,161 frame rings.

What to check:

- Does QuestionPro's script field accept and save it? (validation test 3)
- Does the version stamp appear, showing `v3.0 · 6161 rings`?
- Console should show `indexed 6161 rings in N ms`. If N is above ~100ms on
  desktop, index-building on mobile may be noticeable.
- Type `st mary oxford`. v2 would have returned nothing on real Dove data;
  v3 should return the Oxford St Marys.

If the field rejects the size, the fallbacks in order are: drop the
alternative-names column (saves ~11KB), host the payload externally and fetch
it (adds a network dependency and a CORS surface mid-questionnaire), or revert
to cascading county questions.

---

## Step 1 — value capture

**The one that matters most.** Everything else is usability; this is whether
the census gets data at all.

Select a tower, submit, then open Analytics → Raw Data or an export and
confirm the field contains e.g. `Henley on Thames, S Mary (6) — Oxfordshire [30]`.

**Do not accept the green confirmation as evidence.** It proves the click
handler ran, nothing more. If QuestionPro's form layer is framework-controlled,
`native.value = x` can be overwritten on the next render and the response
submits empty with no error anywhere.

v3 dispatches both `input` and `change` events, which covers more frameworks
than v2's `change` alone. If capture still fails, the next thing to try is the
native setter approach:

```js
var setter = Object.getOwnPropertyDescriptor(
  window.HTMLInputElement.prototype, "value").set;
setter.call(native, item.value);
native.dispatchEvent(new Event("input", { bubbles: true }));
```

which is the standard workaround for React-controlled inputs.

---

## Step 2 — bind to the question explicitly

v3 takes the **first** visible text input wider than 50px, which is correct on
a single-question page and a guess everywhere else. v2 took the *last*, which
was simply a bug.

Once the tower question exists in the real survey, find its input's `name` or
`id` in the browser inspector and set:

```js
inputSelector: 'input[name="q_12345"]'
```

Until that is set, do not put another text question on the same page.

---

## Step 3 — mobile

Real iOS device and real Android device. Not desktop responsive mode, which
does not reproduce the virtual keyboard's effect on the visual viewport.

Expected problem: `position:fixed` positioned from `getBoundingClientRect()`
while the on-screen keyboard resizes the viewport. iOS Safari is the likely
failure.

If it fails, the options are `visualViewport` event listeners to reposition,
or abandoning the fixed overlay in favour of a full-screen modal on small
screens — which is arguably a better mobile pattern anyway.

---

## Step 4 — back-navigation

Untested and a live risk (see `tower-autocomplete.md`, Defect 1). The teardown
removes the widget when the native input leaves the DOM; nothing re-injects it.

Test: select a tower, go forward a page, come back.

- Widget reappears → QuestionPro re-runs Pre JavaScript Logic on
  back-navigation. Nothing to do.
- Bare text box containing the composite value → respondents careful enough to
  check their answer get an uncontrolled free-text field. Needs the poll to
  keep running rather than stopping at first bind.

---

## Step 5 — "my tower isn't listed"

Required by D-008 and not yet built. Proposed: a persistent row at the foot of
the results list, and an option shown when a search returns nothing, which
switches the widget to free-text entry and writes
`NOT LISTED: <what they typed>` to the native input.

That keeps it to one QuestionPro field, and the prefix makes the escapes
trivially separable at analysis time for the reconciliation task.

---

## Step 6 — keyboard navigation

Arrow keys to move through results, Enter to select, Escape to dismiss. No
framework needed — a `selectedIndex` variable and a `keydown` handler.

A scope decision rather than a technical one, but shipping without it should
be a logged choice rather than an omission, and the respondent population
skews older.

---

## Step 7 — screen reader support

`role="combobox"` with `aria-expanded`, `aria-controls` and
`aria-activedescendant` on the input; `role="listbox"` and `role="option"` on
the dropdown and its rows; a polite live region announcing result counts.

Depends on step 6 — `aria-activedescendant` needs the keyboard selection model
to point at.

---

## Step 8 — hidden RingID field

Replace the composite `Display [RingID]` with two fields: the display string
visible, the bare `RingID` in a hidden question.

The composite is brittle — any dedication containing square brackets breaks
parsing — and it couples the analysis key to the display format, so changing a
label silently changes the data. Needs Vicki to add a hidden question.

Deferred deliberately: it adds a moving part while the widget itself is still
being stabilised.

---

## Step 9 — production hardening

- `CONFIG.debug = false`.
- Confirm the Dove CC BY-SA attribution is live in the survey's about or
  privacy text (`Q-001`).
- Re-generate from the final frame snapshot and record the build manifest.
- Confirm the deployed script matches `inst/questionnaire/` in the repository.

---

## Keeping the two normalisers in step

`foldKey()` in the JavaScript and `normalise_search_key()` in `R/text.R` must
behave identically, or the search index and the query will disagree about what
a tower is called. They are currently maintained by hand in two languages.

Worth a shared fixture: a small committed CSV of input/expected pairs that
both an R test and a browser console snippet can check. Cheap insurance
against a silent divergence that would only show up as "I can't find my
tower".
