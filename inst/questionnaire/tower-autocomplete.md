# Tower autocomplete widget — QuestionPro

Documentation for `tower_autocomplete.js`, the tower-selection control used in
the Tower Representative and Individual Ringer surveys.

**Status as at 2026-09-19: working prototype, not ready for deployment.**

The approach is proven — it runs in QuestionPro and the search works. What it
has not had is a production build. The defects below include several that
would break the census.

---

## Version

The file here is **v2 plus the page-transition teardown patch**, which is
believed to match what is in QuestionPro's Pre JavaScript Logic field. That
has not been confirmed against the live script. Worth five minutes to diff
them before any further work — the repository copy should be authoritative,
and it can only be that if someone has checked.

---

## Why it exists

The census needs respondents to identify their tower precisely from a frame of
6,161 rings (D-003). Free-text identification would be unusable — there are
dozens of "S Mary" and hundreds of duplicated place names.

QuestionPro's native question types cannot hold the frame:

| Question type | Limit hit |
| --- | --- |
| Lookup Table | Fails at roughly 300 options with `Limit exceeded MAX_ANSWERS_PER_QUESTION` |
| Multi-tier Lookup Table | Accepts more, but caps at roughly 2,000 rows |

### Licensing — this constrains everything

- The QuestionPro **Non-Profit Waiver** licence maps to the **Advanced** tier,
  not Team or Research.
- **JavaScript Logic is only available on Team and Research editions.** It is
  not available on Advanced or on the Non-Profit Waiver.
- Vicki upgraded the account to **Research** tier during development
  specifically to unlock it.

**This is a standing dependency, not a solved problem.** If the licence lapses
or reverts to the waiver tier, the widget stops working and the survey silently
loses its tower question. Worth a calendar check before fieldwork.

An earlier successful test of the Lookup Table with more than 300 options was
most likely run on a trial licence with higher limits — not evidence that the
native control would have worked.

---

## Platform behaviour — hard-won, do not re-derive

Discovered empirically in September 2026. This section is the most valuable
part of this document: every line cost time to establish and none of it is in
QuestionPro's documentation.

1. **The in-editor preview does execute JavaScript Logic.** Confirmed. There
   is no need to publish a survey to test script changes.

2. **`alert()` works; naive DOM insertion does not.** `alert("test")` fires,
   which proves the engine runs. But an element appended with
   `document.body.appendChild(div)` is wiped within about a second by
   QuestionPro's own re-rendering cycle.

3. **Pre and Post JavaScript Logic are not before/after render.** Pre runs
   before the page renders, so anything it injects directly is wiped. Post
   appears to run *after the respondent submits the page*, not after render —
   elements injected there never appear at all. **Use Pre.**

4. **`setTimeout` alone does not help.** A 1500ms delayed insertion into the
   form or body was still wiped. The re-render is not a single early event to
   wait past.

5. **`setInterval` polling plus `position:fixed` is the pattern that works.**
   Poll every 500ms until the native text input exists, then inject the widget
   as `position:fixed` with a high `z-index`. A fixed-position element sits
   outside the normal layout flow and survives the re-render.

6. **Fixed elements also survive page transitions — which is a bug, not a
   feature.** QuestionPro uses SPA-style navigation rather than full page
   loads, so the widget persists onto the next page of the survey and floats
   over it. The fix, applied in the current script, is a second poll checking
   `document.body.contains(native)`; when the original input leaves the DOM,
   the widget removes itself and detaches its listeners. Note the teardown's
   own leaks under *Defects 11a–c*, and that nothing re-injects the widget on
   back-navigation (*Defect 1*).

7. **The overlay must track its anchor.** Because it is positioned from the
   native input's `getBoundingClientRect()`, it needs a `reposition()` handler
   on `scroll` with `useCapture: true` and on `resize`, or it detaches from
   the field it represents.

---

## How it works

1. The script runs as an IIFE from the question's Pre JavaScript Logic.
2. A tower array `T` is embedded in the script — one entry per ring, as
   `[id, place, dedication, county]`.
3. An index `items` is built once, each entry carrying a `label` (shown), a
   `value` (written to the response) and a `search` string.
4. `setInterval` polls at 500ms until a text input is present.
5. The real QuestionPro input is hidden (`opacity:0`, `pointerEvents:none`)
   but left in the DOM so QP still submits its value.
6. A `position:fixed` overlay is appended to `document.body` and positioned
   from the hidden input's bounding rect.
7. Typing filters the index: query lowercased, split on whitespace, an item
   matches when **every** token appears in its search string. Multi-term
   search works — "mary oxford" finds the St Mary towers in Oxfordshire. Top
   12 shown, with an "N more" hint.
8. Clicking a row writes `value` into the hidden input, dispatches a `change`
   event, and shows a green confirmation.

## Data contract

```js
[id, place, dedication, county]
```

- `label` — `"<place>, <dedication> (<county>)"`, what the respondent sees.
- `value` — `label + " [" + id + "]"`, what lands in the response data.
- `search` — `"<place> <dedication> <county>"`, lowercased.

## Attribution obligation

The embedded array is a substantial extract of Dove's Guide, which is CC BY-SA
4.0. Attribution must be visible to the respondent, in the survey's about or
privacy text — not only in this repository. Wording is `DOVE_ATTRIBUTION` in
`scripts/00_setup.R`. Tracked as `Q-001`.

---

## Companion scripts

| Script | Role |
| --- | --- |
| `dove_to_qp_js.py` | Reads `dove.csv` and generates the `var T = [...]` array. **Not in this repository.** |
| `dove_to_questionpro.py` | Earlier script generating per-county files for the Multi-tier Lookup Table. Superseded, kept as fallback. **Not in this repository.** |

Both should be replaced by `scripts/05_export_questionnaire_towers.R`, so the
payload is built from the same frozen snapshot as the analysis, with the same
provenance record. Until then there is no guarantee that what respondents
choose from matches what the analysis weights to.

Note that `dove.cccbr.org.uk` is not reachable from Claude's sandboxed
environments, so the CSV is always fetched by a human or by
`scripts/01_fetch_dove.R` running locally.

---

## Defects

Ranked by what they would do to the census.

### Blocking

**1. Back-navigation is untested, and is the gap in the teardown.**

The teardown removes the widget when the native input leaves the DOM. Nothing
puts it back. If a respondent uses the survey's Back button to revisit the
tower question, the outcome depends on whether QuestionPro re-executes Pre
JavaScript Logic on SPA back-navigation, which is not established.

- If it does re-run, a fresh widget is injected and all is well.
- If it does not, the respondent sees a bare text input containing
  `"Henley on Thames, S Mary (Oxfordshire) [30]"` — editable as free text,
  with no validation, and no way back to the picker.

The second outcome quietly converts a controlled field into free text for
exactly the respondents careful enough to go back and check their answer.
**This belongs in the validation set as a fourth test.** The saved
`GoBackSurvey` capture in the census folder suggests back-navigation was
already being looked at.

**2. It binds to the wrong input on any multi-question page.**

```js
if (inputs[j].offsetWidth > 50) { native = inputs[j]; }
```

No `break`, so this selects the **last** text input wider than 50px anywhere
in the document — not the one belonging to this question. It works in a
single-question preview and silently attaches to the wrong field as soon as
the page has another text input. Fix: select by the question's QuestionPro
element id or name, not by geometry.

**3. There is no safety net.** The native input is hidden before the overlay
is built. If anything throws between those two steps, the respondent sees a
question with no visible input and no way to proceed. The body needs a
`try`/`catch` restoring the native input's styles on any error, so the worst
case is a plain text box.

**4. Value capture is unverified and may silently fail.** Setting `.value` and
dispatching a native `change` event does not reliably notify a
framework-controlled input. If QuestionPro's form layer is React-based, the
assignment is overwritten on the next render and the response submits empty,
with no error anywhere. This is validation test 1 (`Q-002`) and it must be
tested by **submitting a real response and reading it back from the export** —
the confirmation message proves only that the click handler ran.

**5. Search will fail against real Dove data.** The sample array uses expanded
dedications — `"S Mary the Virgin"`, `"Cathedral Ch of Christ"`. Real Dove has
`"S Mary V"`, `"Cath Ch of Christ"`, `"S Edmund K&M"`. Under D-009 the display
keeps Dove's abbreviations, so a respondent typing `"st mary"` matches
**nothing**: `search` contains `"s mary v"` and `indexOf("st")` fails.

The prototype's sample data was flattering. `search` must be built with the
same normalisation as `normalise_search_key()` in `R/text.R` — folding
`saint`/`s`/`ss` to `st`, stripping apostrophes and diacritics, normalising
`&` — and **the query must be folded identically at keystroke time**. That
means a JavaScript port of that function, and two implementations to keep in
step. Generating the JS normaliser from the same rules, or testing both
against a shared fixture, is worth the effort.

**6. No "my tower isn't listed" escape.** D-008 requires one.

### Serious

**7. No keyboard navigation.** No arrow keys, no Enter, no Escape. Mouse and
touch only. In a population skewing older this is a completion risk.

**8. No screen-reader support.** No `role="combobox"`, `aria-expanded`,
`aria-activedescendant`, or live region. A screen-reader user cannot complete
the question.

**9. Mobile is the likeliest failure.** `position:fixed` positioned from
`getBoundingClientRect()` interacts badly with the virtual keyboard, which
resizes the visual viewport on focus. iOS Safari is notably bad at this.
Validation test 2 (`Q-002`).

**10. The captured value is a composite string, not a clean identifier.** The
response receives `"Abingdon, S Helen (Berkshire) [1]"`. Recoverable by regex
but brittle — any place or dedication containing square brackets breaks
parsing — and it couples the analysis key to the display format, so changing
the label silently changes the data. Preferred: bare `RingID` to a hidden
field, display string to the visible one.

**11. The poll never gives up.** If no input is found, `setInterval` runs
every 500ms for the life of the page. It needs a timeout, after which it
clears itself and leaves the native input visible and usable.

### Serious — leaks in the teardown

**11a. The teardown's own `setInterval` is never cleared.**

```js
setInterval(function() { reposition(); }, 1000);
```

No handle is kept, so it cannot be stopped. After the widget is removed it
carries on firing every second for the life of the page, taking the
`!document.body.contains(native)` branch each time. Harmless per tick — the
`box.parentNode &&` guard stops the double-removal throwing — but on a
multi-page survey the intervals accumulate, one per page visited.

Fix: keep the id and clear it in the teardown branch.

```js
var tidy = setInterval(function() { reposition(); }, 1000);
// ...and inside the teardown branch:
clearInterval(tidy);
```

**11b. The outside-click handler is never removed.**

```js
document.addEventListener("click", function(e) {
  if (!box.contains(e.target)) { drop.style.display = "none"; }
});
```

It closes over `box`, so the detached element cannot be garbage-collected
after teardown, and the handler keeps running on every click on every
subsequent page. Name the function and remove it alongside the scroll and
resize listeners.

**11c. There is a one-second window where the widget floats.** The teardown
poll runs at 1000ms, so on transition the overlay sits over the next page
until the next tick. Cosmetic, but visible, and a respondent who clicks it in
that window is clicking a dead control. Hooking the Next button as well as
polling would close it.

### Minor

**12. The label omits bell count.** On real data, place + dedication + county
leaves 16 colliding rows. Adding bells reduces that to 2. Label should be
`"<place>, <dedication> (<bells>) — <county>"`.

**13. No alternative names in `search`.** Dove's `AltName` is populated for
489 frame rings and carries what people actually call the place — `Exmouth`
for Withycombe Raleigh, `Groes Ffordd` for Gresford. Costs about 11KB.

**14. Payload was never the constraint it was feared to be.** Measured on the
`dove_2026-09-19` snapshot: **286KB** as newline-delimited `id|display`, 297KB
with alternative names, 372KB as a JSON array of objects — against the
400–600KB that prompted concern. Validation test 3 is still worth running, but
the external-hosting fallback is now unlikely to be needed. Note that external
hosting would also add a network dependency and a CORS surface in the middle
of the respondent's journey, so avoiding it is worth something.

---

## Before this is deployed

1. Diff this file against the live QuestionPro script and make this
   repository authoritative.
2. Fix defects 1–6 and the teardown leaks 11a–c.
3. Run the validation tests (`Q-002`) — **four, not three**: value capture
   verified by reading back submitted response data; mobile on real devices;
   full-payload acceptance; and back-navigation to the tower question.
4. Move payload generation into `scripts/05_export_questionnaire_towers.R`.
5. Decide 7 and 8 — a scope call, not a technical one, but shipping without
   keyboard and screen-reader support should be a logged decision rather than
   an omission.
6. Test on a real iOS device, not a desktop browser's responsive mode.
7. Confirm the Dove attribution is live in the survey text (`Q-001`).
8. Confirm the QuestionPro licence will still be Research tier at fieldwork.

## Fallback

**Cascading county-based questions.** Q1 selects county (~60 options); Q2
shows a conditional Lookup Table filtered to that county, comfortably under
the 2,000 cap. Native features only, works on every tier, reliable on mobile.
Build cost is roughly 60 lookup questions plus branching wiring.

**Also worth trying: ask QuestionPro support to raise the per-question
limit.** It is likely a database parameter rather than an architectural
constraint, and a support ticket is cheap next to either of the other paths.

The fallback should not be discarded until the validation tests pass on real
devices. Reverting close to fieldwork would be expensive, so the decision
point needs to come early enough to act on — see the open question on setting
that date.
