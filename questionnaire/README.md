# Tower autocomplete widgets — QuestionPro

Documentation for the two tower-selection controls in the Tower
Representative and Individual Ringer surveys:

| Widget | Source | Use | Saves |
| --- | --- | --- | --- |
| Single picker | `tower_autocomplete.js` (v4.4) | One tower: "Where do you ring?" | `Amersham, S Mary V (12) — Buckinghamshire [4914]` |
| Multi picker | `tower_multipicker.js` (m2.0) | Several towers: "Which towers count you as a band member?", "Where did you ring in census week?" | The same composite per tower, separated by ` \| ` |

**Never paste the source files.** Paste the builds that
`questionnaire/build_widgets.R` writes to `build/`. The source files carry
the comments that explain the code, and with them they exceed QuestionPro's
size limit (see *Platform behaviour*, item 9).

**Status as at 2026-10-11: both widgets work end to end, at full scale.**
The single picker (v4.4) serves the 6,297-ring picker (D-018) from GitHub
Pages (D-021). Typing `St Mary Amersham` returns `Amersham, S Mary V (12) —
Buckinghamshire`; selections reach the response export with their RingID;
tested on desktop and on iPhone 13 Safari. The multi picker (m2.0) worked
on a real phone on 2026-10-11, up to its 12-tower cap. Its values reached the
export in an early test version's bare-ID format (`17319;4640`); **the
composite format m2.0 saves has not yet been checked in an export.**

The version lives in `CFG.version`, shown in the debug stamp and every console
line — not in the filename. Earlier versions are in git history, and the reasons
they were superseded are in D-015 and D-016.

Not yet production-ready: see *Outstanding* below.

---

## Architecture

Each widget is a script in its question's **Pre JavaScript Logic**: about
13,400 characters for the single picker and 17,900 for the multi picker, as
pasted. The tower list is **not** in them — it is fetched at runtime from a hosted plain-text
file (D-015, D-016).

```
QuestionPro page
  └─ Pre JavaScript Logic  (14 KB widget)
       ├─ fetch()  ──────────►  towers_<snapshot>.txt   (304 KB, ~80 KB gzipped)
       ├─ local copy (keyed by URL) — checked once per questionnaire (D-025)
       └─ overlay injected over the hidden native input
```

### Why the list cannot be embedded

QuestionPro's limits, established empirically by pasting padded scripts of
known size rather than by asking:

| Field | Limit |
| --- | --- |
| JavaScript Logic | between **19,012 and 20,841** characters (19,012 accepted, 20,841 rejected, 2026-10-10) |
| Rich-text content block | **10,000** characters, counting injected markup |

Encodings measured against the real 6,161-ring frame:

| Scheme | Size |
| --- | --- |
| Plain `id\|display\|alt` | 304 KB |
| Dictionary-encode dedication + county | 166 KB |
| …plus prefix-coding the sorted place column | 144 KB |
| gzip + base64 | 88 KB |

Against roughly 19 KB of payload budget, the smallest is seven times too big.
A request to raise the platform limit was refused. Chunking across ten hidden
content blocks was prototyped and worked, and was rejected as too fragile to
maintain — see D-015.

---

## Platform behaviour — hard-won, do not re-derive

Established empirically in September 2026. None of it is in QuestionPro's
documentation.

1. **The in-editor preview does execute JavaScript Logic.** No need to publish
   a survey to test.
2. **`alert()` works; naive DOM insertion does not.** An element appended with
   `document.body.appendChild` is wiped within about a second by QuestionPro's
   re-rendering.
3. **Pre and Post are not before/after render.** Pre runs before render, so
   anything injected directly is wiped. Post appears to run *after the
   respondent submits the page*. **Use Pre.**
4. **`setTimeout` alone does not help.** A 1500 ms delayed insertion was still
   wiped; the re-render is not a single early event to wait past.
5. **`setInterval` polling plus `position:fixed` is what works.** Poll until
   the native input exists, then inject as fixed with a high `z-index`. A fixed
   element is outside the layout flow and survives the re-render.
6. **Fixed elements also survive page transitions — a bug, not a feature.**
   Navigation is SPA-style, so the overlay floats over the next page unless torn
   down. v4 watches for the native input leaving the DOM and removes itself,
   clearing its interval and listeners.
7. **The overlay must track its anchor** via `reposition()` on `scroll` (with
   `useCapture: true`) and `resize`.
8. **Outbound requests are permitted.** `fetch` returned HTTP 200 in 61 ms and a
   `<script>` tag loaded in 63 ms, with no CSP violation. The only CSP messages
   in the console are QuestionPro's own report-only `frame-ancestors` and an
   unrelated `SyntaxError` in their `util-tag.js`.

9. **JavaScript Logic has a size limit between 19,012 and 20,841
   characters.** The 20,841-character multi picker was refused on paste; the
   19,012-character single picker is accepted. Hence the paste builds:
   `questionnaire/build_widgets.R` strips whole-line comments and refuses
   any build above 19,012.
10. **The preview runs the survey inside a frame called `surveyFrame`.** In
    the browser console, switch the context dropdown from `top` to
    `surveyFrame` before inspecting anything. From `top`, the question inputs
    appear not to exist, and QuestionPro's own wrapper shows five unrelated
    boxes, `customValue1`–`5`.
11. **Every question's Pre JS in a block runs when the block loads**, not
    when each question appears. Two pickers in one block start together,
    race to claim inputs, and both fetch the list before either has marked
    the tab as checked. **Put each picker in its own block.** Splitting the
    block fixed a multi picker that appeared to save nothing (2026-10-10).
12. **On a phone, the question scrolls inside its own panel, not the page.**
    A fixed overlay sits outside that panel, so a swipe on the overlay
    scrolls nothing. An overlay that grows until it covers the panel leaves
    the respondent unable to reach either the search box or Next. **Rule:
    the part of a widget floating over the page must stay small** — no
    larger than the single picker's box and confirmation. Three layouts of
    the multi picker failed this on a real phone before m2.0.
13. **QuestionPro caps the native input's height.** A plain `style.height`
    stopped growing at about four towers. Setting `height`, `min-height` and
    `max-height` with `!important` overrides it.
14. **A text answer of at least 1,000 characters is saved intact**
    (2026-10-10). Twelve composite tower values, about 750 characters, fit.

---

## The data file

Generated by `questionnaire/publish_tower_list.R` from the curated frame.

```
# dove_2026-09-19 6161 298766
2575|Ab Kettleby, S James (6) — Leicestershire|
6154|Abbey Dore, S Mary (6) — Herefordshire|Abbeydore
```

Header is `# <snapshot_id> <n_rings> <n_chars>`; each row is
`RingID|display|alt names`. Alternative names are searched but never
displayed — they carry what people actually call a place (`Exmouth` for
Withycombe Raleigh, `Groes Ffordd` for Gresford).

Integrity is by counts, not a checksum. Counts catch truncation and a partial
cache write; HTTPS prevents corruption in transit; the snapshot id catches the
wrong file; and a hash cannot detect tampering by anyone able to edit the
header. See D-016.

**Live URL**, served by GitHub Pages from `docs/` (D-021):

```
https://cccbr.github.io/census2026/towers_dove_2026-09-19.txt
```

Published by `questionnaire/publish_tower_list.R`, which also regenerates
the index page at <https://cccbr.github.io/census2026/>. If the site moves to a
`cccbr.org.uk` subdomain, decide that before fieldwork: GitHub would redirect the
old address, but a redirect is one more thing that can fail in reference week.

---

## The multi picker

The page shows only a small box: a green summary of at most two lines
("✓ 4 towers: Amersham, S Mary V (12); Hatfield Heath, Holy Trinity (6); …")
and a button, **Choose towers…** or **Add or change towers**. The button
opens a **full-screen panel** (a centred column up to 600 px wide on a
desktop) with the search box at the top, results and chosen towers in one
scrolling area, and a large **Done** fixed at the bottom.

This design follows from platform item 12. Three earlier layouts kept the
growing list on the page, and on a real phone each one ended with the list
covering Next or the search box. The panel scrolls itself, so nothing
underneath can trap the respondent, and what stays on the page is no bigger
than the single picker.

| Behaviour | Detail |
| --- | --- |
| Saved value | Composite values in selection order, separated by ` \| ` (D-030). The pipe cannot appear in a label, because the list file uses it as its field separator |
| Parsing | Split on `\|`, trim, then take the RingID from the `[...]` at the **end** of each part. Anchoring to the end makes a bracket inside a dedication harmless |
| Cap | 12 towers (D-030). The search box disables at the cap, with a message |
| Duplicates | A chosen tower is never offered again |
| Tags | Show place, dedication and bells, without the county, cut off with "…". The full label is in the tooltip and in the saved value |
| Keyboard | Opens automatically only when the list is empty, and closes after each choice so the new tag is visible |
| Back-navigation | The widget rebuilds its list from the native value. It also reads the bare-ID format of early test versions (`17319;4640`) |
| Failure | With no list, the native box returns with a note asking for towers separated by semicolons. These answers join the free-text reconciliation task |

It shares the single picker's stored list and once-per-tab check (D-025), so
on the second picker in a questionnaire it costs no network at all.

---

## Search

`foldKey()` in **both** widgets **must stay in step with
`normalise_search_key()` in `R/text.R`** — three copies of one function. Both fold `saint`/`S`/`SS` to `st`, strip apostrophes and
diacritics, and normalise `&`. Index and query pass through the same function
so they meet in the middle.

This is not cosmetic. Dove writes `S Mary V`; ringers type `st marys`. Without
folding, the search returns nothing — which v2 did, invisibly, because its
sample data used expanded dedications.

| Query | Hits |
| --- | --- |
| `st mary oxford` | 52 |
| `ss peter and paul` | 208 |
| `exmouth` | 2 |
| `ynys mon` | 2 |

---

## Failure handling

- **Checked once per questionnaire** (D-025). The first picker in a browser tab
  asks the server whether the list has changed — normally a tiny "not modified"
  reply. Every later picker in that tab uses the stored copy with **no network
  at all**, which matters in the individual survey on weak rural signal. A
  respondent resuming next day through Save & Continue Later is in a new tab,
  so is checked again. **Nobody is ever asked to clear anything**; a tester who
  republishes the list just opens the survey in a new tab.
- **Timeouts depend on what failure costs.** With nothing stored, the widget
  waits up to **20 seconds**, because the alternative is free text. With a
  stored copy, it gives up after **3 seconds** and uses the copy.
- **Stored copy.** Kept in `localStorage` under a key built from the URL. Each
  successful load deletes any other stored list, including the fixed-key copy
  written by versions before v4.4. If the stored copy is used because the
  network failed, the tab is still marked as checked, so a failing connection
  costs one wait, not one at every picker.

  *Correction:* earlier versions of this document described the cache as "keyed
  by snapshot". It was not — the key was fixed, and the cache was consulted
  *before* the network, so testers saw a stale list until they cleared browser
  storage by hand. Both fixed in v4.4.
- **Degraded path**: on timeout, network failure, malformed header or count
  mismatch, the native input is restored and a message asks for place name and
  dedication. Never a dead question. These responses are separable at analysis
  and join the free-text reconciliation task.
- **Error safety net**: any exception during construction restores the native
  input, so the worst case is a plain text box.

---

## Outstanding

### Blocking before fieldwork

1. ~~Value capture~~ — **passed.** The response backend shows
   `Amersham, S Mary V (12) — Buckinghamshire [4914]`, RingID included.
2. **Bind to the question explicitly.** The widget takes the first visible text input
   wider than 50 px — correct on a single-question page, a guess elsewhere. Set
   `CFG.inputSelector` once the real question's `name` is known. Until then, do
   not put another text question on the same page.
3. ~~Mobile~~ — **passed** on iPhone 13 Safari, despite the prediction that
   `position:fixed` would fail there. Android and a small phone in landscape are
   still untested.
4. **Back-navigation untested.** Teardown removes the widget; nothing
   re-injects it. If QuestionPro does not re-run Pre JS on back-navigation, a
   respondent who goes back gets an uncontrolled free-text field containing the
   composite value. See Q-011.
5. **"My tower isn't listed" escape** is required by D-008 and not built.
6. ~~Hosting~~ — **done** (D-021). Retire the test copy on the personal
   `Ainsworld` account so nothing still points there.

### Multi picker, before fieldwork

- **Check m2.0's composite value in the export** — only the early bare-ID
  format has been seen there.
- **Feedback from the team** on m2.0 (Mark, 2026-10-11: "works a treat").
- **Android and a small phone in landscape**, especially whether the
  keyboard pushes Done off the screen while typing.
- **Binding** (item 2 above) applies equally: set `CFG.inputSelector`.
- **"Not listed" escape** (item 5) needs a multi-picker form too.
- **The tower list fetch timed out** after 3 seconds on two loads in a row on
  2026-10-10, against 61 ms in September. Harmless with a stored copy; a
  first-time respondent would wait up to 20 seconds. Check the Network tab.

### Deferred deliberately

Keyboard navigation, screen-reader support and the hidden-RingID field. All in
`todo.md`, to be worked one step at a time — debugging inside QuestionPro is
slow and batching changes makes failures hard to attribute.

---

## Attribution

The tower list is a substantial extract of Dove's Guide, CC BY-SA 4.0.
Attribution must be visible to the respondent in the survey's about or privacy
text, not only in this repository. Wording is `DOVE_ATTRIBUTION` in
`scripts/00_setup.R`. Tracked as Q-001.
