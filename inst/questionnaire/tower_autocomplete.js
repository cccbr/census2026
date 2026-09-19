// DOVE TOWER AUTOCOMPLETE — QuestionPro Pre JavaScript Logic
// Paste this entire script into Pre JavaScript Logic.
// Uses setInterval to wait for QP to finish rendering,
// then injects a fixed-position autocomplete overlay.
//
// -----------------------------------------------------------------------
// STATUS: WORKING PROTOTYPE. NOT READY FOR DEPLOYMENT.
//
// Captured into the repository 2026-09-19. This is v2 plus the page-
// transition teardown patch, believed to match what is in QuestionPro —
// but that has not been confirmed against the live script field.
//
// It carries 50 SAMPLE towers, not the 6,161-ring frame, and has known
// blocking defects — wrong-input binding, no error safety net, unverified
// value capture, and a search index that will not match real Dove
// abbreviations.
//
// READ inst/questionnaire/tower-autocomplete.md BEFORE CHANGING OR
// DEPLOYING THIS. Do not treat the absence of errors in QuestionPro
// preview as evidence that it works.
// -----------------------------------------------------------------------

(function() {

  // === SAMPLE TOWER DATA (replace with full set from dove_to_qp_js.py) ===
  var T = [
    [1,"Abingdon","S Helen","Berkshire"],
    [2,"Abingdon","S Nicolas","Berkshire"],
    [3,"Adderbury","S Mary","Oxfordshire"],
    [4,"Amersham","S Mary","Buckinghamshire"],
    [5,"Appleton","S Laurence","Berkshire"],
    [6,"Aston Rowant","S Peter and S Paul","Oxfordshire"],
    [7,"Aylesbury","S Mary","Buckinghamshire"],
    [8,"Banbury","S Mary","Oxfordshire"],
    [9,"Beaconsfield","S Mary and All Saints","Buckinghamshire"],
    [10,"Bicester","S Edburg","Oxfordshire"],
    [11,"Bladon","S Martin","Oxfordshire"],
    [12,"Bloxham","Our Lady of Bloxham","Oxfordshire"],
    [13,"Bray","S Michael","Berkshire"],
    [14,"Brightwell cum Sotwell","S Agatha","Oxfordshire"],
    [15,"Brill","All Saints","Buckinghamshire"],
    [16,"Buckingham","S Peter and S Paul","Buckinghamshire"],
    [17,"Burford","S John Baptist","Oxfordshire"],
    [18,"Caversham","S Peter","Oxfordshire"],
    [19,"Charlbury","S Mary","Oxfordshire"],
    [20,"Chesham","S Mary","Buckinghamshire"],
    [21,"Chinnor","S Andrew","Oxfordshire"],
    [22,"Chipping Norton","S Mary","Oxfordshire"],
    [23,"Cholsey","S Mary","Oxfordshire"],
    [24,"Deddington","S Peter and S Paul","Oxfordshire"],
    [25,"Dorchester","S Peter and S Paul","Oxfordshire"],
    [26,"Drayton","S Peter","Berkshire"],
    [27,"East Hagbourne","S Andrew","Oxfordshire"],
    [28,"Eynsham","S Leonard","Oxfordshire"],
    [29,"Great Missenden","S Peter and S Paul","Buckinghamshire"],
    [30,"Henley on Thames","S Mary","Oxfordshire"],
    [31,"High Wycombe","All Saints","Buckinghamshire"],
    [32,"Iffley","S Mary","Oxfordshire"],
    [33,"Kidlington","S Mary","Oxfordshire"],
    [34,"Long Crendon","S Mary","Buckinghamshire"],
    [35,"Marlow","All Saints","Buckinghamshire"],
    [36,"North Hinksey","S Lawrence","Oxfordshire"],
    [37,"Oxford","Cathedral Ch of Christ","Oxfordshire"],
    [38,"Oxford","S Giles","Oxfordshire"],
    [39,"Oxford","S Mary Magdalen","Oxfordshire"],
    [40,"Oxford","S Mary the Virgin","Oxfordshire"],
    [41,"Oxford","S Thomas the Martyr","Oxfordshire"],
    [42,"Princes Risborough","S Mary","Buckinghamshire"],
    [43,"Reading","S Giles","Berkshire"],
    [44,"Reading","S Laurence","Berkshire"],
    [45,"Reading","S Mary","Berkshire"],
    [46,"Steeple Aston","S Peter and S Paul","Oxfordshire"],
    [47,"Thame","S Mary","Oxfordshire"],
    [48,"Wallingford","S Mary le More","Oxfordshire"],
    [49,"Wantage","SS Peter and Paul","Oxfordshire"],
    [50,"Witney","S Mary","Oxfordshire"]
  ];

  // Build search index
  var items = [];
  for (var i = 0; i < T.length; i++) {
    var id = T[i][0], pl = T[i][1], ded = T[i][2], co = T[i][3];
    var label = pl + ", " + ded + " (" + co + ")";
    items.push({
      label: label,
      value: label + " [" + id + "]",
      search: (pl + " " + ded + " " + co).toLowerCase()
    });
  }

  // Wait for QP to finish rendering, then inject
  var ready = false;
  var check = setInterval(function() {
    if (ready) return;

    // Find the text input for this question
    var inputs = document.querySelectorAll('input[type="text"]');
    var native = null;
    for (var j = 0; j < inputs.length; j++) {
      // Skip tiny/hidden inputs; find the visible survey answer input
      if (inputs[j].offsetWidth > 50) {
        native = inputs[j];
      }
    }
    if (!native) return;

    ready = true;
    clearInterval(check);

    // Hide native input
    native.style.opacity = "0";
    native.style.position = "absolute";
    native.style.pointerEvents = "none";

    // Get position of native input to place our widget
    var rect = native.getBoundingClientRect();

    // Create container
    var box = document.createElement("div");
    box.style.cssText =
      "position:fixed; z-index:999999; background:#fff; " +
      "left:" + rect.left + "px; top:" + rect.top + "px; " +
      "width:" + Math.max(rect.width, 300) + "px;";

    // Search input
    var inp = document.createElement("input");
    inp.type = "text";
    inp.placeholder = "Type your tower name…";
    inp.setAttribute("autocomplete", "off");
    inp.setAttribute("autocorrect", "off");
    inp.style.cssText =
      "width:100%; padding:10px 12px; font-size:16px; " +
      "border:2px solid #ccc; border-radius:6px; " +
      "box-sizing:border-box; outline:none; font-family:inherit;";

    // Results dropdown
    var drop = document.createElement("div");
    drop.style.cssText =
      "max-height:220px; overflow-y:auto; border:1px solid #ddd; " +
      "border-top:none; border-radius:0 0 6px 6px; background:#fff; " +
      "display:none; box-shadow:0 4px 12px rgba(0,0,0,0.15);";

    // Selection confirmation
    var conf = document.createElement("div");
    conf.style.cssText =
      "display:none; margin-top:6px; padding:8px 12px; " +
      "background:#e8f5e9; border:1px solid #a5d6a7; " +
      "border-radius:6px; font-size:14px; color:#2e7d32;";

    box.appendChild(inp);
    box.appendChild(drop);
    box.appendChild(conf);
    document.body.appendChild(box);

    // Reposition on scroll/resize, remove if page moves on
    //
    // QuestionPro uses SPA-style navigation, so a position:fixed overlay
    // survives page transitions and floats over the next page. This teardown
    // watches for the native input leaving the DOM. See the "leaks" note in
    // tower-autocomplete.md — the interval below is never cleared, and the
    // outside-click handler is never removed.
    function reposition() {
      if (!document.body.contains(native)) {
        box.parentNode && box.parentNode.removeChild(box);
        window.removeEventListener("scroll", reposition, true);
        window.removeEventListener("resize", reposition);
        return;
      }
      var r = native.getBoundingClientRect();
      box.style.left = r.left + "px";
      box.style.top = r.top + "px";
      box.style.width = Math.max(r.width, 300) + "px";
    }
    window.addEventListener("scroll", reposition, true);
    window.addEventListener("resize", reposition);
    setInterval(function() { reposition(); }, 1000);

    // Search logic
    function doSearch() {
      var q = inp.value.toLowerCase().split(/\s+/);
      drop.innerHTML = "";
      if (inp.value.length < 2) { drop.style.display = "none"; return; }

      var hits = items.filter(function(it) {
        return q.every(function(t) { return it.search.indexOf(t) !== -1; });
      });

      if (hits.length === 0) {
        drop.style.display = "block";
        drop.innerHTML = '<div style="padding:10px;color:#999;font-style:italic;font-size:14px;">No matching towers</div>';
        return;
      }

      drop.style.display = "block";
      var show = hits.slice(0, 12);
      for (var k = 0; k < show.length; k++) {
        (function(item) {
          var row = document.createElement("div");
          row.style.cssText =
            "padding:8px 12px; cursor:pointer; font-size:14px; " +
            "border-bottom:1px solid #f0f0f0;";
          row.textContent = item.label;
          row.addEventListener("mouseenter", function() {
            row.style.background = "#e3f2fd";
          });
          row.addEventListener("mouseleave", function() {
            row.style.background = "#fff";
          });
          row.addEventListener("click", function(e) {
            e.preventDefault();
            // Write to native input
            native.value = item.value;
            try {
              var ev = new Event("change", {bubbles:true});
              native.dispatchEvent(ev);
            } catch(ex) {}
            // Update UI
            inp.value = item.label;
            inp.style.borderColor = "#4caf50";
            drop.style.display = "none";
            conf.style.display = "block";
            conf.innerHTML = "✓ <strong>" + item.label +
              "</strong><br><span style='font-size:12px;color:#666;'>" +
              "Not right? Clear the box and search again.</span>";
          });
          drop.appendChild(row);
        })(show[k]);
      }

      if (hits.length > 12) {
        var more = document.createElement("div");
        more.style.cssText = "padding:8px 12px;color:#999;font-size:13px;font-style:italic;";
        more.textContent = (hits.length - 12) + " more — keep typing to narrow down";
        drop.appendChild(more);
      }
    }

    inp.addEventListener("input", function() {
      if (native.value) {
        native.value = "";
        conf.style.display = "none";
        inp.style.borderColor = "#ccc";
      }
      doSearch();
    });

    // Close dropdown on outside click
    document.addEventListener("click", function(e) {
      if (!box.contains(e.target)) { drop.style.display = "none"; }
    });

    inp.addEventListener("focus", function() {
      if (!native.value) inp.style.borderColor = "#2196f3";
    });

  }, 500);

})();
