// tower_autocomplete v4.4 - PASTE BUILD of questionnaire/src/tower_autocomplete.js. Do not edit; rebuild with questionnaire/build_widgets.R.
(function () {
  "use strict";
  var CFG = {
    version: "v4.4",
    dataUrl: "https://cccbr.github.io/census2026/towers_dove_2026-09-19.txt",
    debug: true,
    timeoutNoCopyMs: 20000,
    timeoutWithCopyMs: 3000,
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
      fetch(url, { credentials: "omit", cache: "no-cache" })
        .then(function (r) {
          if (!r.ok) throw new Error("HTTP " + r.status);
          return r.text();
        })
        .then(ok)
        .catch(function (e) { bad(e.message || "fetch failed"); });
    } else {
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
  function sessionKey() { return "ringing_census_checked|" + CFG.dataUrl; }
  function checkedThisSession() {
    try { return window.sessionStorage.getItem(sessionKey()) === "1"; } catch (e) { return false; }
  }
  function markChecked() {
    try { window.sessionStorage.setItem(sessionKey(), "1"); } catch (e) {}
  }
  function loadData() {
    var cached = cacheRead();
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
        markChecked();
        log("using the local copy from an earlier visit");
      } else {
        dataErr = err;
        log("no usable local copy - degrading to free text");
      }
      if (onData) onData();
    });
  }
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
  function build(native) {
    native.style.opacity = "0";
    native.style.pointerEvents = "none";
    native.style.boxSizing = "border-box";
    function viewportWidth() {
      return window.innerWidth || document.documentElement.clientWidth;
    }
    function boxWidth(r) {
      return Math.max(Math.min(Math.max(r.width, 300), viewportWidth() - 16), 180);
    }
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
    function syncHeight() {
      var h = inp.offsetHeight;
      if (conf.style.display !== "none") h += conf.offsetHeight + 6;
      if (stamp) h += stamp.offsetHeight + 4;
      native.style.height = h + "px";
    }
    syncHeight();
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
