// =============================================================================
// DOVE TOWER AUTOCOMPLETE — QuestionPro Pre JavaScript Logic
// Version 3.0 — 2026-09-19
//
// TEMPLATE. The __TOWER_DATA__ placeholder below is filled by
// scripts/05_export_questionnaire_towers.R. Do not paste this file into
// QuestionPro; paste the generated file from inst/questionnaire/build/.
//
// Changes from v2 + teardown patch — critical fixes only. Everything else is
// in inst/questionnaire/todo.md, to be worked through one step at a time.
//
//   1. Search key folding, so Dove's own abbreviations are findable.
//      v2 could not match "st mary" against "S Mary V". This was fatal on
//      real data and invisible on the expanded sample data.
//   2. Binds to the FIRST suitable input, not the last. v2's loop had no
//      break and silently attached to the wrong field on multi-question
//      pages.
//   3. Error safety net. Any failure restores the native input, so the worst
//      case is a plain text box rather than a question with no input at all.
//   4. Teardown no longer leaks: its interval is cleared and the
//      outside-click handler is removed.
//   5. Poll gives up after a timeout instead of running forever.
//   6. Debug mode: console logging and an on-screen version stamp, so you can
//      tell which paste is live.
//
// Deliberately NOT changed, pending single-step work — see todo.md:
//   keyboard navigation, ARIA, "my tower isn't listed" escape, hidden-field
//   RingID capture, back-navigation re-injection.
//
// Tower data from Dove's Guide for Church Bell Ringers
// (https://dove.cccbr.org.uk), (c) the Central Council of Church Bell
// Ringers, licensed CC BY-SA 4.0. Filtered to the census frame and
// reformatted.
// =============================================================================

(function () {
  "use strict";

  var CONFIG = {
    version: "v3.0",
    // Set false before fieldwork. Logs to console and shows a version stamp.
    debug: true,
    // Leave null to auto-detect. Set to a CSS selector to bind explicitly —
    // this is the robust option once the question's id is known.
    inputSelector: null,
    minChars: 2,
    maxResults: 12,
    pollMs: 500,
    pollTimeoutMs: 20000,
    tidyMs: 1000
  };

  // id|display|altnames, newline-delimited. Generated — do not hand-edit.
  var DATA = __TOWER_DATA__;

  function log() {
    if (!CONFIG.debug || !window.console) return;
    var a = Array.prototype.slice.call(arguments);
    a.unshift("[tower " + CONFIG.version + "]");
    console.log.apply(console, a);
  }

  // ---------------------------------------------------------------------------
  // Search key folding.
  //
  // MUST stay in step with normalise_search_key() in R/text.R. Ringers type
  // the way they speak: Dove writes "S Mary V", they type "st marys". Both
  // the index and the query are folded through this, so they meet in the
  // middle.
  //
  // Order matters and mirrors the R version: transliterate, lowercase,
  // ampersand, saint forms, apostrophes, everything else to spaces.
  // ---------------------------------------------------------------------------
  function foldKey(s) {
    if (!s) return "";
    var out = s;
    try {
      out = out.normalize("NFD").replace(/[̀-ͯ]/g, "");
    } catch (e) {
      // normalize() is unavailable on some very old browsers; diacritics then
      // simply stay, which degrades matching rather than breaking it.
    }
    return out
      .toLowerCase()
      .replace(/&/g, " and ")
      .replace(/\bsaints?\b/g, "st")
      .replace(/\bss?\.?(?=\s|$)/g, "st")
      .replace(/['’]/g, "")
      .replace(/[^a-z0-9]+/g, " ")
      .replace(/\s+/g, " ")
      .replace(/^\s+|\s+$/g, "");
  }

  // ---- build the index ------------------------------------------------------

  var items = [];
  (function buildIndex() {
    var t0 = (window.performance && performance.now) ? performance.now() : 0;
    var lines = DATA.split("\n");
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i]) continue;
      var p = lines[i].split("|");
      if (p.length < 2) continue;
      var id = p[0], display = p[1], alt = p[2] || "";
      items.push({
        id: id,
        label: display,
        value: display + " [" + id + "]",
        search: foldKey(display + " " + alt)
      });
    }
    var t1 = (window.performance && performance.now) ? performance.now() : 0;
    log("indexed", items.length, "rings in", Math.round(t1 - t0), "ms");
  })();

  // ---- find the question's input -------------------------------------------

  function findInput() {
    if (CONFIG.inputSelector) {
      return document.querySelector(CONFIG.inputSelector);
    }
    var inputs = document.querySelectorAll('input[type="text"]');
    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      // First visible, reasonably-sized, not already claimed.
      if (el.offsetWidth > 50 && el.offsetParent !== null && !el.getAttribute("data-tower-bound")) {
        return el;
      }
    }
    return null;
  }

  // ---- injection ------------------------------------------------------------

  var started = Date.now();
  var poll = setInterval(function () {
    var native = null;
    try {
      native = findInput();
    } catch (e) {
      log("findInput threw", e);
    }

    if (!native) {
      if (Date.now() - started > CONFIG.pollTimeoutMs) {
        clearInterval(poll);
        log("gave up after", CONFIG.pollTimeoutMs, "ms — no input found");
      }
      return;
    }

    clearInterval(poll);
    native.setAttribute("data-tower-bound", "1");
    log("bound to input", native.name || native.id || "(unnamed)");

    try {
      build(native);
    } catch (e) {
      // Safety net. Never leave the respondent with a hidden input and no
      // widget — a plain text box is a bad experience, a dead question is a
      // lost response.
      restore(native);
      log("build failed, native input restored", e);
    }
  }, CONFIG.pollMs);

  function restore(native) {
    if (!native) return;
    native.style.opacity = "";
    native.style.position = "";
    native.style.pointerEvents = "";
  }

  function build(native) {
    native.style.opacity = "0";
    native.style.position = "absolute";
    native.style.pointerEvents = "none";

    var rect = native.getBoundingClientRect();

    var box = document.createElement("div");
    box.style.cssText =
      "position:fixed; z-index:999999; background:#fff; " +
      "left:" + rect.left + "px; top:" + rect.top + "px; " +
      "width:" + Math.max(rect.width, 300) + "px;";

    var inp = document.createElement("input");
    inp.type = "text";
    inp.placeholder = "Type your tower name…";
    inp.setAttribute("autocomplete", "off");
    inp.setAttribute("autocorrect", "off");
    inp.setAttribute("autocapitalize", "off");
    inp.setAttribute("spellcheck", "false");
    inp.style.cssText =
      "width:100%; padding:10px 12px; font-size:16px; " +
      "border:2px solid #ccc; border-radius:6px; " +
      "box-sizing:border-box; outline:none; font-family:inherit;";

    var drop = document.createElement("div");
    drop.style.cssText =
      "max-height:220px; overflow-y:auto; border:1px solid #ddd; " +
      "border-top:none; border-radius:0 0 6px 6px; background:#fff; " +
      "display:none; box-shadow:0 4px 12px rgba(0,0,0,0.15);";

    var conf = document.createElement("div");
    conf.style.cssText =
      "display:none; margin-top:6px; padding:8px 12px; " +
      "background:#e8f5e9; border:1px solid #a5d6a7; " +
      "border-radius:6px; font-size:14px; color:#2e7d32;";

    box.appendChild(inp);
    box.appendChild(drop);
    box.appendChild(conf);

    if (CONFIG.debug) {
      var stamp = document.createElement("div");
      stamp.style.cssText =
        "margin-top:4px; font-size:11px; color:#999; font-family:monospace;";
      stamp.textContent = CONFIG.version + " · " + items.length + " rings";
      box.appendChild(stamp);
    }

    document.body.appendChild(box);

    // ---- teardown ----------------------------------------------------------
    // QuestionPro navigates SPA-style, so a position:fixed overlay survives
    // page transitions and floats over the next page. Watch for the native
    // input leaving the DOM, then remove everything — including this
    // interval and the document-level click handler, both of which leaked in
    // the v2 patch.

    var tidy = null;
    var torn = false;

    function teardown() {
      if (torn) return;
      torn = true;
      if (box.parentNode) box.parentNode.removeChild(box);
      window.removeEventListener("scroll", reposition, true);
      window.removeEventListener("resize", reposition);
      document.removeEventListener("click", onDocClick);
      if (tidy) clearInterval(tidy);
      log("torn down");
    }

    function reposition() {
      if (!document.body.contains(native)) { teardown(); return; }
      var r = native.getBoundingClientRect();
      box.style.left = r.left + "px";
      box.style.top = r.top + "px";
      box.style.width = Math.max(r.width, 300) + "px";
    }

    function onDocClick(e) {
      if (!box.contains(e.target)) drop.style.display = "none";
    }

    window.addEventListener("scroll", reposition, true);
    window.addEventListener("resize", reposition);
    document.addEventListener("click", onDocClick);
    tidy = setInterval(reposition, CONFIG.tidyMs);

    // ---- search ------------------------------------------------------------

    function doSearch() {
      var raw = inp.value;
      drop.innerHTML = "";
      if (raw.length < CONFIG.minChars) { drop.style.display = "none"; return; }

      // The query is folded exactly as the index was, so "st mary" matches
      // "S Mary V" and "ynys mon" matches "Ynys Mon".
      var q = foldKey(raw).split(" ");
      var hits = [];
      for (var i = 0; i < items.length; i++) {
        var s = items[i].search, ok = true;
        for (var j = 0; j < q.length; j++) {
          if (q[j] && s.indexOf(q[j]) === -1) { ok = false; break; }
        }
        if (ok) hits.push(items[i]);
      }

      drop.style.display = "block";

      if (hits.length === 0) {
        drop.innerHTML =
          '<div style="padding:10px;color:#999;font-style:italic;font-size:14px;">' +
          "No matching towers</div>";
        return;
      }

      var show = hits.slice(0, CONFIG.maxResults);
      for (var k = 0; k < show.length; k++) {
        drop.appendChild(makeRow(show[k]));
      }
      if (hits.length > CONFIG.maxResults) {
        var more = document.createElement("div");
        more.style.cssText =
          "padding:8px 12px;color:#999;font-size:13px;font-style:italic;";
        more.textContent = (hits.length - CONFIG.maxResults) +
          " more — keep typing to narrow down";
        drop.appendChild(more);
      }
    }

    function makeRow(item) {
      var row = document.createElement("div");
      row.style.cssText =
        "padding:8px 12px; cursor:pointer; font-size:14px; " +
        "border-bottom:1px solid #f0f0f0;";
      row.textContent = item.label;
      row.addEventListener("mouseenter", function () { row.style.background = "#e3f2fd"; });
      row.addEventListener("mouseleave", function () { row.style.background = "#fff"; });
      row.addEventListener("click", function (e) {
        e.preventDefault();
        select(item);
      });
      return row;
    }

    function select(item) {
      native.value = item.value;
      try {
        native.dispatchEvent(new Event("input",  { bubbles: true }));
        native.dispatchEvent(new Event("change", { bubbles: true }));
      } catch (ex) {
        // Older browsers: fall back to the legacy construction.
        try {
          var ev = document.createEvent("HTMLEvents");
          ev.initEvent("change", true, false);
          native.dispatchEvent(ev);
        } catch (ex2) { log("could not dispatch change", ex2); }
      }
      inp.value = item.label;
      inp.style.borderColor = "#4caf50";
      drop.style.display = "none";
      conf.style.display = "block";
      conf.innerHTML = "✓ <strong>" + item.label +
        "</strong><br><span style='font-size:12px;color:#666;'>" +
        "Not right? Clear the box and search again.</span>";
      log("selected", item.id, item.label, "-> native.value =", native.value);
    }

    inp.addEventListener("input", function () {
      if (native.value) {
        native.value = "";
        conf.style.display = "none";
        inp.style.borderColor = "#ccc";
      }
      doSearch();
    });

    inp.addEventListener("focus", function () {
      if (!native.value) inp.style.borderColor = "#2196f3";
    });

    log("widget built");
  }

})();
