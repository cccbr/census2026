// tower_multipicker m2.0 - PASTE BUILD of questionnaire/src/tower_multipicker.js. Do not edit; rebuild with questionnaire/build_widgets.R.
(function () {
  "use strict";
  var CFG = {
    version: "m2.0",
    dataUrl: "https://cccbr.github.io/census2026/towers_dove_2026-09-19.txt",
    debug: true,
    timeoutNoCopyMs: 20000,
    timeoutWithCopyMs: 3000,
    cachePrefix: "ringing_census_towers|",
    minChars: 2,
    maxResults: 12,
    maxSelections: 12,
    separator: " | ",
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
      note.textContent = "The tower list could not be loaded. Please type each " +
        "tower's place name and dedication, separated by semicolons, for example: " +
        "Banbury, S Mary; Bloxham, S Mary.";
      native.parentNode && native.parentNode.appendChild(note);
    } catch (e) {}
  }
  function build(native) {
    native.style.opacity = "0";
    native.style.pointerEvents = "none";
    native.style.boxSizing = "border-box";
    var byId = {};
    for (var b = 0; b < items.length; b++) byId[items[b].id] = items[b];
    var chosen = [];
    (native.value || "").split(/[|;]/).forEach(function (part) {
      var m = part.match(/\[([^\[\]]+)\]\s*$/), id = m ? m[1] : part.replace(/^\s+|\s+$/g, "");
      if (id && byId[id] && chosen.indexOf(byId[id]) < 0) chosen.push(byId[id]);
    });
    function el(tag, css, text) {
      var e = document.createElement(tag);
      if (css) e.style.cssText = css;
      if (text) e.textContent = text;
      return e;
    }
    function shortName(item) { return item.label.split(" — ")[0]; }
    function writeNative() {
      var vals = [];
      for (var i = 0; i < chosen.length; i++) vals.push(chosen[i].value);
      native.value = vals.join(CFG.separator);
      try {
        native.dispatchEvent(new Event("input", { bubbles: true }));
        native.dispatchEvent(new Event("change", { bubbles: true }));
      } catch (ex) { log("could not dispatch events", ex); }
      log("native.value =", native.value || "(empty)");
    }
    function viewportWidth() {
      return window.innerWidth || document.documentElement.clientWidth;
    }
    function boxWidth(r) {
      return Math.max(Math.min(Math.max(r.width, 300), viewportWidth() - 16), 180);
    }
    function boxLeft(r, w) {
      return Math.max(Math.min(r.left, viewportWidth() - w - 8), 8);
    }
    var r0 = native.getBoundingClientRect(), w0 = boxWidth(r0);
    var box = el("div", "position:fixed;z-index:999999;background:#fff;left:" +
      boxLeft(r0, w0) + "px;top:" + r0.top + "px;width:" + w0 + "px;");
    var summary = el("div", "padding:8px 12px;font-size:14px;color:#2e7d32;background:#e8f5e9;" +
      "border:1px solid #a5d6a7;border-radius:6px;margin-bottom:6px;overflow:hidden;" +
      "display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;");
    var openBtn = el("button", "width:100%;min-height:44px;padding:10px 12px;font-size:16px;" +
      "border:2px solid #2196f3;border-radius:6px;background:#fff;color:#1565c0;" +
      "font-family:inherit;cursor:pointer;");
    openBtn.type = "button";
    box.appendChild(summary); box.appendChild(openBtn);
    var stamp = null;
    if (CFG.debug) {
      stamp = el("div", "margin-top:4px;font-size:11px;color:#999;font-family:monospace;");
      box.appendChild(stamp);
    }
    document.body.appendChild(box);
    function syncHeight() {
      var h = box.offsetHeight;
      native.style.setProperty("max-height", "none", "important");
      native.style.setProperty("min-height", h + "px", "important");
      native.style.setProperty("height", h + "px", "important");
    }
    function renderSummary() {
      if (chosen.length) {
        var names = [];
        for (var i = 0; i < chosen.length; i++) names.push(shortName(chosen[i]));
        summary.style.display = "-webkit-box";
        summary.textContent = "✓ " + chosen.length + (chosen.length === 1 ? " tower: " : " towers: ") +
          names.join("; ");
        openBtn.textContent = "Add or change towers";
      } else {
        summary.style.display = "none";
        openBtn.textContent = "Choose towers…";
      }
      if (stamp) stamp.textContent = CFG.version + " · " + chosen.length + " chosen";
      syncHeight();
    }
    var shade = null, inp = null, results = null, list = null, count = null;
    function openPanel() {
      if (shade) return;
      shade = el("div", "position:fixed;top:0;left:0;right:0;bottom:0;z-index:1000000;" +
        "background:rgba(0,0,0,.4);");
      var panel = el("div", "position:absolute;top:0;bottom:0;left:50%;transform:translateX(-50%);" +
        "width:100%;max-width:600px;background:#fff;display:flex;flex-direction:column;" +
        "font-family:inherit;box-sizing:border-box;");
      panel.setAttribute("role", "dialog");
      panel.setAttribute("aria-modal", "true");
      panel.setAttribute("aria-label", "Choose towers");
      var top = el("div", "flex:none;padding:12px 16px 8px;border-bottom:1px solid #eee;");
      count = el("div", "font-size:14px;color:#666;margin-bottom:8px;");
      inp = el("input", "width:100%;padding:10px 12px;font-size:16px;border:2px solid #2196f3;" +
        "border-radius:6px;box-sizing:border-box;outline:none;font-family:inherit;");
      inp.type = "text";
      inp.setAttribute("autocomplete", "off");
      inp.setAttribute("autocorrect", "off");
      inp.setAttribute("autocapitalize", "off");
      inp.setAttribute("spellcheck", "false");
      inp.setAttribute("aria-label", "Search for a tower");
      top.appendChild(count); top.appendChild(inp);
      var body = el("div", "flex:1;overflow-y:auto;-webkit-overflow-scrolling:touch;" +
        "overscroll-behavior:contain;padding:0 16px;");
      results = el("div");
      list = el("div", "display:flex;flex-wrap:wrap;padding:12px 0;");
      body.appendChild(results); body.appendChild(list);
      var foot = el("div", "flex:none;padding:12px 16px;border-top:1px solid #eee;");
      var done = el("button", "width:100%;min-height:48px;font-size:18px;font-weight:bold;border:none;" +
        "border-radius:6px;background:#e8540f;color:#fff;font-family:inherit;cursor:pointer;", "Done");
      done.type = "button";
      done.addEventListener("click", function (e) { e.preventDefault(); closePanel(); });
      foot.appendChild(done);
      panel.appendChild(top); panel.appendChild(body); panel.appendChild(foot);
      shade.appendChild(panel);
      document.body.appendChild(shade);
      inp.addEventListener("input", doSearch);
      shade.addEventListener("keydown", function (e) {
        if (e.key === "Escape") closePanel();
      });
      renderPanel();
      if (!chosen.length) inp.focus();
      log("panel opened");
    }
    function closePanel() {
      if (!shade) return;
      if (shade.parentNode) shade.parentNode.removeChild(shade);
      shade = inp = results = list = count = null;
      renderSummary();
      log("panel closed with", chosen.length);
    }
    function renderPanel() {
      if (!shade) return;
      var full = chosen.length >= CFG.maxSelections;
      inp.disabled = full;
      inp.style.background = full ? "#f5f5f5" : "#fff";
      inp.placeholder = full ? "Limit reached - remove one to add another" :
        (chosen.length ? "Add another tower…" : "Type a tower name…");
      count.textContent = chosen.length
        ? chosen.length + (chosen.length === 1 ? " tower chosen" : " towers chosen") +
          ". Add more, or press Done."
        : "Search for each tower, then press Done.";
      list.innerHTML = "";
      for (var i = 0; i < chosen.length; i++) list.appendChild(makeTag(chosen[i]));
    }
    function makeTag(item) {
      var tag = el("div", "display:inline-flex;align-items:center;max-width:100%;" +
        "margin:0 6px 6px 0;background:#e8f5e9;border:1px solid #a5d6a7;border-radius:20px;");
      var lab = el("div", "padding:0 0 0 12px;font-size:14px;color:#2e7d32;white-space:nowrap;" +
        "overflow:hidden;text-overflow:ellipsis;min-width:0;", shortName(item));
      lab.title = item.label;
      var x = el("button", "flex:none;width:44px;height:44px;border:none;background:none;" +
        "font-size:22px;line-height:1;color:#666;cursor:pointer;", "×");
      x.type = "button";
      x.setAttribute("aria-label", "Remove " + item.label);
      x.addEventListener("click", function (e) {
        e.preventDefault(); e.stopPropagation();
        chosen.splice(chosen.indexOf(item), 1);
        writeNative(); renderPanel();
      });
      tag.appendChild(lab); tag.appendChild(x);
      return tag;
    }
    function doSearch() {
      results.innerHTML = "";
      if (inp.value.length < CFG.minChars) return;
      var q = foldKey(inp.value).split(" "), hits = [];
      for (var i = 0; i < items.length; i++) {
        if (chosen.indexOf(items[i]) >= 0) continue;
        var s = items[i].search, ok = true;
        for (var j = 0; j < q.length; j++) {
          if (q[j] && s.indexOf(q[j]) === -1) { ok = false; break; }
        }
        if (ok) hits.push(items[i]);
      }
      if (!hits.length) {
        results.appendChild(el("div", "padding:12px 0;color:#999;font-style:italic;font-size:14px;",
          "No matching towers"));
        return;
      }
      var show = hits.slice(0, CFG.maxResults);
      for (var k = 0; k < show.length; k++) results.appendChild(makeRow(show[k]));
      if (hits.length > CFG.maxResults) {
        results.appendChild(el("div", "padding:8px 0;color:#999;font-size:13px;font-style:italic;",
          (hits.length - CFG.maxResults) + " more — keep typing to narrow down"));
      }
    }
    function makeRow(item) {
      var row = el("div", "padding:12px 4px;cursor:pointer;font-size:15px;" +
        "border-bottom:1px solid #f0f0f0;", item.label);
      row.addEventListener("click", function (e) { e.preventDefault(); select(item); });
      return row;
    }
    function select(item) {
      if (chosen.length >= CFG.maxSelections || chosen.indexOf(item) >= 0) return;
      chosen.push(item);
      writeNative();
      inp.value = "";
      results.innerHTML = "";
      inp.blur();
      renderPanel();
      log("added", item.id, "- now", chosen.length);
    }
    var tidy = null, torn = false;
    function teardown() {
      if (torn) return;
      torn = true;
      closePanel();
      if (box.parentNode) box.parentNode.removeChild(box);
      window.removeEventListener("scroll", reposition, true);
      window.removeEventListener("resize", reposition);
      if (tidy) clearInterval(tidy);
      log("torn down");
    }
    function reposition() {
      if (!document.body.contains(native)) { teardown(); return; }
      var r = native.getBoundingClientRect(), w = boxWidth(r);
      box.style.left = boxLeft(r, w) + "px";
      box.style.top = r.top + "px";
      box.style.width = w + "px";
      if (native.offsetHeight < box.offsetHeight) syncHeight();
    }
    window.addEventListener("scroll", reposition, true);
    window.addEventListener("resize", reposition);
    tidy = setInterval(reposition, CFG.tidyMs);
    openBtn.addEventListener("click", function (e) { e.preventDefault(); openPanel(); });
    renderSummary();
    log("widget built,", chosen.length, "restored from native value");
  }
})();
