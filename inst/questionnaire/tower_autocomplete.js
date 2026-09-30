// =============================================================================
// DOVE TOWER AUTOCOMPLETE v4 — QuestionPro Pre JavaScript Logic
//
// Loads the tower list from an external file instead of embedding it, because
// QuestionPro caps JS Logic at ~16-32k characters and content blocks at 10,000.
//
// Set CFG.dataUrl below, then paste this whole file into Pre JavaScript Logic.
// Full notes: inst/questionnaire/tower-autocomplete.md
// =============================================================================

(function () {
  "use strict";

  var CFG = {
    version: "v4.4",
    // The generated data file: PLAIN TEXT, fetched and parsed as data.
    // Deliberately not a .js loaded by script tag — that would execute remote
    // code in the respondent's browser, so a compromised host could run
    // anything on a page collecting census responses. Fetching data means the
    // worst case is bad data, which the checksum catches.
    // The host must send Access-Control-Allow-Origin (jsDelivr does).
    dataUrl: "https://cccbr.github.io/census2026/towers_dove_2026-09-19.txt",
    debug: true,
    // How long to wait for the list. It depends on what failure costs:
    // with no stored copy the alternative is free text, which is worse data
    // than a slow picker - so be patient on weak rural signal. With a stored
    // copy the alternative is nearly as good, so give up quickly.
    timeoutNoCopyMs: 20000,
    timeoutWithCopyMs: 3000,
    // Local copies are keyed by URL, so a new list never collides with an old one.
    cachePrefix: "ringing_census_towers|",
    minChars: 2,
    maxResults: 12,
    pollMs: 500,
    pollTimeoutMs: 20000,
    tidyMs: 1000
  };

  function log() {
    if (!CFG.debug || !window.console) return;
    var a = [].slice.call(arguments); a.unshift("[tower " + CFG.version + "]");
    console.log.apply(console, a);
  }

  // ---- search key folding -------------------------------------------------
  // MUST stay in step with normalise_search_key() in R/text.R. Ringers type
  // "st marys" where Dove writes "S Mary V"; both sides fold through this.
  function foldKey(s) {
    if (!s) return "";
    var o = s;
    try { o = o.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) {}
    return o.toLowerCase()
      .replace(/&/g, " and ")
      .replace(/\bsaints?\b/g, "st")
      .replace(/\bss?\.?(?=\s|$)/g, "st")
      .replace(/['’]/g, "")
      .replace(/[^a-z0-9]+/g, " ")
      .replace(/\s+/g, " ")
      .replace(/^\s+|\s+$/g, "");
  }

  // ---- data loading -------------------------------------------------------
  //
  // Integrity is checked by row count and character count, not a hash.
  //
  // A hash would add almost nothing here. The realistic failures are
  // truncation and a partial localStorage write, both of which the counts
  // catch. Corruption in transit is prevented by HTTPS; the wrong file being
  // served is caught by the snapshot id in the header; and a hash cannot
  // detect tampering, because anyone able to alter the file can alter the
  // header too.
  //
  // Against that, a 32-bit hash would have to be reimplemented identically in
  // R — which has no native unsigned 32-bit arithmetic — creating exactly the
  // kind of silent cross-language divergence already being managed with
  // foldKey(). Not worth it.

  var items = null, dataErr = null, onData = null;

  function buildIndex(payload) {
    var t0 = Date.now(), out = [], lines = payload.split("\n");
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i]) continue;
      var p = lines[i].split("|");
      if (p.length < 2) continue;
      out.push({
        id: p[0], label: p[1],
        value: p[1] + " [" + p[0] + "]",
        search: foldKey(p[1] + " " + (p[2] || ""))
      });
    }
    log("indexed", out.length, "rings in", Date.now() - t0, "ms");
    return out;
  }

  function accept(obj, source) {
    if (obj.c !== obj.d.length) {
      log("LENGTH MISMATCH from " + source + ": got " + obj.d.length +
          " chars, header declares " + obj.c + " - payload is truncated");
      return false;
    }
    var idx = buildIndex(obj.d);
    if (idx.length !== obj.n) {
      log("ROW COUNT MISMATCH from " + source + ": indexed " + idx.length +
          ", header declares " + obj.n);
      return false;
    }
    items = idx;
    log("loaded", obj.n, "rings from", source, "snapshot", obj.v);
    return true;
  }

  // The file is plain text. First line is a header, the rest is the payload:
  //   # <snapshot_id> <n_rings> <n_chars>
  //   <ringid>|<display>|<alt names>
  //   ...
  // Readable with curl, greppable, and reusable by anything that isn't this
  // widget — which a JSON blob or a .js assignment would not be.
  function parse(text) {
    var nl = text.indexOf("\n");
    if (nl < 0) return null;
    var head = text.slice(0, nl).trim().split(/\s+/);
    if (head[0] !== "#" || head.length < 4) return null;
    return { v: head[1], n: +head[2], c: +head[3], d: text.slice(nl + 1) };
  }

  function cacheKey() { return CFG.cachePrefix + CFG.dataUrl; }

  function cacheRead() {
    try {
      var raw = window.localStorage.getItem(cacheKey());
      return raw ? parse(raw) : null;
    } catch (e) { return null; }
  }

  // Store this list, and delete every other list this widget has cached -
  // including the single fixed-key copy written by versions before v4.4, which
  // is what left testers stuck on an old list until they cleared it by hand.
  function cacheWrite(text) {
    try {
      var ls = window.localStorage, stale = [], i;
      for (i = 0; i < ls.length; i++) {
        var k = ls.key(i);
        if (k && k.indexOf("ringing_census_towers") === 0 && k !== cacheKey()) stale.push(k);
      }
      for (i = 0; i < stale.length; i++) ls.removeItem(stale[i]);
      ls.setItem(cacheKey(), text);
      if (stale.length) log("removed", stale.length, "stale cached list(s)");
    } catch (e) {}
  }

  function fetchText(url, ms, cb) {
    var done = false;
    var t = setTimeout(function () { if (!done) { done = true; cb(null, "timeout"); } }, ms);
    function ok(txt)  { if (done) return; done = true; clearTimeout(t); cb(txt, null); }
    function bad(why) { if (done) return; done = true; clearTimeout(t); cb(null, why); }

    if (window.fetch) {
      // "no-cache" makes the browser check with the server every time rather
      // than trusting its own copy. When the list is unchanged the server
      // answers "not modified" and nothing is re-downloaded; when it has been
      // republished, the new list arrives. No one ever has to clear anything.
      fetch(url, { credentials: "omit", cache: "no-cache" })
        .then(function (r) {
          if (!r.ok) throw new Error("HTTP " + r.status);
          return r.text();
        })
        .then(ok)
        .catch(function (e) { bad(e.message || "fetch failed"); });
    } else {
      // Older browsers. XHR is subject to the same CORS rules as fetch.
      try {
        var x = new XMLHttpRequest();
        x.open("GET", url, true);
        x.onload = function () {
          (x.status >= 200 && x.status < 300) ? ok(x.responseText) : bad("HTTP " + x.status);
        };
        x.onerror = function () { bad("network"); };
        x.send();
      } catch (e) { bad("xhr threw"); }
    }
  }

  // ONCE PER QUESTIONNAIRE (D-025).
  //
  // The first picker in a browser session checks the list against the server
  // (a revalidating fetch - normally a tiny "not modified" reply). Every later
  // picker in the same session uses the stored copy with no network at all,
  // which matters in the individual survey, where the picker can appear several
  // times on a weak rural connection.
  //
  // "Session" is the browser tab: it survives QuestionPro's page changes and
  // ends when the tab closes, so a respondent who resumes tomorrow via Save &
  // Continue Later is checked again. A tester who republishes the list needs
  // only to open the survey in a new tab.
  function sessionKey() { return "ringing_census_checked|" + CFG.dataUrl; }
  function checkedThisSession() {
    try { return window.sessionStorage.getItem(sessionKey()) === "1"; } catch (e) { return false; }
  }
  function markChecked() {
    try { window.sessionStorage.setItem(sessionKey(), "1"); } catch (e) {}
  }

  function loadData() {
    var cached = cacheRead();
    // Cheap integrity test to decide the timeout; the full check runs on use.
    var haveCopy = !!(cached && cached.d && cached.c === cached.d.length);

    if (haveCopy && checkedThisSession()) {
      if (accept(cached, "this session's copy")) { if (onData) onData(); return; }
      haveCopy = false;
    }

    var timeout = haveCopy ? CFG.timeoutWithCopyMs : CFG.timeoutNoCopyMs;
    log("fetching", CFG.dataUrl, "- timeout", timeout, "ms");
    fetchText(CFG.dataUrl, timeout, function (text, err) {
      if (!err) {
        var obj = parse(text);
        if (obj && accept(obj, "network")) {
          cacheWrite(text);
          markChecked();
          if (onData) onData();
          return;
        }
        err = obj ? "count mismatch" : "malformed header";
      }
      log("network load failed -", err);
      if (haveCopy && accept(cached, "local copy")) {
        // Mark the session checked even on this path: on a failing connection,
        // retrying at every later picker would cost the respondent another wait
        // each time for a list they already have.
        markChecked();
        log("using the local copy from an earlier visit");
      } else {
        // Not marked: with nothing stored, the next picker tries again.
        dataErr = err;
        log("no usable local copy - degrading to free text");
      }
      if (onData) onData();
    });
  }

  // ---- find the question's input -----------------------------------------

  function findInput() {
    if (CFG.inputSelector) return document.querySelector(CFG.inputSelector);
    var ins = document.querySelectorAll('input[type="text"]');
    for (var i = 0; i < ins.length; i++) {
      var el = ins[i];
      if (el.offsetWidth > 50 && el.offsetParent !== null && !el.getAttribute("data-tower-bound")) return el;
    }
    return null;
  }

  function restore(n) {
    if (!n) return;
    n.style.opacity = ""; n.style.position = ""; n.style.pointerEvents = "";
  }

  loadData();

  var started = Date.now();
  var poll = setInterval(function () {
    var native = null;
    try { native = findInput(); } catch (e) { log("findInput threw", e); }
    if (!native) {
      if (Date.now() - started > CFG.pollTimeoutMs) {
        clearInterval(poll); log("gave up - no input found");
      }
      return;
    }
    clearInterval(poll);
    native.setAttribute("data-tower-bound", "1");
    log("bound to", native.name || native.id || "(unnamed)");

    if (items) { start(native); }
    else if (dataErr) { degrade(native); }
    else { onData = function () { items ? start(native) : degrade(native); }; }
  }, CFG.pollMs);

  function start(native) {
    try { build(native); }
    catch (e) { restore(native); log("build failed, native input restored", e); }
  }

  // No tower list: leave a usable text box rather than a dead question, and
  // label it so these responses are separable at analysis time.
  function degrade(native) {
    restore(native);
    log("DEGRADED to free text -", dataErr);
    try {
      var note = document.createElement("div");
      note.style.cssText = "margin-top:6px;padding:8px 12px;background:#fff8e1;" +
        "border:1px solid #ffe082;border-radius:6px;font-size:13px;color:#795548;";
      note.textContent = "The tower list could not be loaded. Please type your " +
        "tower's place name and dedication, for example: Banbury, S Mary.";
      native.parentNode && native.parentNode.appendChild(note);
    } catch (e) {}
  }

  // ---- widget -------------------------------------------------------------

  function build(native) {
    // Hide the native input but LEAVE IT IN FLOW. Setting position:absolute
    // here removes it from the layout, so everything below it - the progress
    // button, the "save and continue later" link - moves up underneath the
    // fixed overlay. syncHeight() below then keeps the reserved space equal to
    // the overlay's persistent height.
    native.style.opacity = "0";
    native.style.pointerEvents = "none";
    native.style.boxSizing = "border-box";

    // Prefer 300px, but never wider than the space actually available - a
    // forced minimum overflows narrow containers and covers whatever sits to
    // the right of the question.
    function viewportWidth() {
      return window.innerWidth || document.documentElement.clientWidth;
    }
    function boxWidth(r) {
      return Math.max(Math.min(Math.max(r.width, 300), viewportWidth() - 16), 180);
    }
    // If the box cannot fit starting at the input's left edge, slide it left
    // rather than shrinking it below a usable width.
    function boxLeft(r, w) {
      return Math.max(Math.min(r.left, viewportWidth() - w - 8), 8);
    }

    var stamp = null;
    var r0 = native.getBoundingClientRect();
    var box = document.createElement("div");
    var w0 = boxWidth(r0);
    box.style.cssText = "position:fixed;z-index:999999;background:#fff;left:" +
      boxLeft(r0, w0) + "px;top:" + r0.top + "px;width:" + w0 + "px;";

    var inp = document.createElement("input");
    inp.type = "text";
    inp.placeholder = "Type your tower name…";
    inp.setAttribute("autocomplete", "off");
    inp.setAttribute("autocorrect", "off");
    inp.setAttribute("autocapitalize", "off");
    inp.setAttribute("spellcheck", "false");
    inp.style.cssText = "width:100%;padding:10px 12px;font-size:16px;border:2px solid #ccc;" +
      "border-radius:6px;box-sizing:border-box;outline:none;font-family:inherit;";

    var drop = document.createElement("div");
    drop.style.cssText = "max-height:220px;overflow-y:auto;border:1px solid #ddd;border-top:none;" +
      "border-radius:0 0 6px 6px;background:#fff;display:none;box-shadow:0 4px 12px rgba(0,0,0,.15);";

    var conf = document.createElement("div");
    conf.style.cssText = "display:none;margin-top:6px;padding:8px 12px;background:#e8f5e9;" +
      "border:1px solid #a5d6a7;border-radius:6px;font-size:14px;color:#2e7d32;";

    box.appendChild(inp); box.appendChild(drop); box.appendChild(conf);
    if (CFG.debug) {
      stamp = document.createElement("div");
      stamp.style.cssText = "margin-top:4px;font-size:11px;color:#999;font-family:monospace;";
      stamp.textContent = CFG.version + " · " + items.length + " rings";
      box.appendChild(stamp);
    }
    document.body.appendChild(box);

    // Reserve flow space equal to the overlay's PERSISTENT height. The dropdown
    // is transient and may overlap - that is ordinary autocomplete behaviour -
    // but the confirmation box stays on screen and must not cover the page.
    function syncHeight() {
      var h = inp.offsetHeight;
      if (conf.style.display !== "none") h += conf.offsetHeight + 6;
      if (stamp) h += stamp.offsetHeight + 4;
      native.style.height = h + "px";
    }
    syncHeight();

    // Teardown. QuestionPro navigates SPA-style, so a fixed overlay survives
    // page transitions and floats over the next page unless removed.
    var tidy = null, torn = false;
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
      var w = boxWidth(r);
      box.style.left = boxLeft(r, w) + "px";
      box.style.top = r.top + "px";
      box.style.width = w + "px";
    }
    function onDocClick(e) { if (!box.contains(e.target)) drop.style.display = "none"; }
    window.addEventListener("scroll", reposition, true);
    window.addEventListener("resize", reposition);
    document.addEventListener("click", onDocClick);
    tidy = setInterval(reposition, CFG.tidyMs);

    function doSearch() {
      drop.innerHTML = "";
      if (inp.value.length < CFG.minChars) { drop.style.display = "none"; return; }
      var q = foldKey(inp.value).split(" "), hits = [];
      for (var i = 0; i < items.length; i++) {
        var s = items[i].search, ok = true;
        for (var j = 0; j < q.length; j++) {
          if (q[j] && s.indexOf(q[j]) === -1) { ok = false; break; }
        }
        if (ok) hits.push(items[i]);
      }
      drop.style.display = "block";
      if (!hits.length) {
        drop.innerHTML = '<div style="padding:10px;color:#999;font-style:italic;font-size:14px;">No matching towers</div>';
        return;
      }
      var show = hits.slice(0, CFG.maxResults);
      for (var k = 0; k < show.length; k++) drop.appendChild(makeRow(show[k]));
      if (hits.length > CFG.maxResults) {
        var m = document.createElement("div");
        m.style.cssText = "padding:8px 12px;color:#999;font-size:13px;font-style:italic;";
        m.textContent = (hits.length - CFG.maxResults) + " more — keep typing to narrow down";
        drop.appendChild(m);
      }
    }

    function makeRow(item) {
      var row = document.createElement("div");
      row.style.cssText = "padding:8px 12px;cursor:pointer;font-size:14px;border-bottom:1px solid #f0f0f0;";
      row.textContent = item.label;
      row.addEventListener("mouseenter", function () { row.style.background = "#e3f2fd"; });
      row.addEventListener("mouseleave", function () { row.style.background = "#fff"; });
      row.addEventListener("click", function (e) { e.preventDefault(); select(item); });
      return row;
    }

    function select(item) {
      native.value = item.value;
      try {
        native.dispatchEvent(new Event("input", { bubbles: true }));
        native.dispatchEvent(new Event("change", { bubbles: true }));
      } catch (ex) { log("could not dispatch events", ex); }
      inp.value = item.label;
      inp.style.borderColor = "#4caf50";
      drop.style.display = "none";
      conf.style.display = "block";
      conf.innerHTML = "✓ <strong>" + item.label + "</strong><br>" +
        "<span style='font-size:12px;color:#666;'>Not right? Clear the box and search again.</span>";
      syncHeight();
      log("selected", item.id, "-> native.value =", native.value);
    }

    inp.addEventListener("input", function () {
      if (native.value) {
        native.value = ""; conf.style.display = "none"; inp.style.borderColor = "#ccc";
        syncHeight();
      }
      doSearch();
    });
    inp.addEventListener("focus", function () {
      if (!native.value) inp.style.borderColor = "#2196f3";
    });

    log("widget built");
  }

})();
