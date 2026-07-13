# Home-page tile template — replaces the binary monitor widget.
#
# Renders a tile grid mirroring glance's native monitor widget visual:
# centered icon, service name, colored status pill below. No buttons. Status
# colors:
#   up    → positive (green)
#   down  → subdue (gray)
#   error → negative (red)
#
# Icon resolution: simpleicons CDN for `si:` prefix; dashboard-icons (homarr)
# for `di:`. Glance's native `si:foo` parser does the same thing internally;
# custom-api widgets don't support the prefix shorthand so we map here.
# Go text/template has no `dict` helper (that's Sprig), so the prefix dispatch
# is plain if/else.
''
  <style>
    .sb-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr)); gap: 0.6rem; }
    .sb-tile { display: flex; flex-direction: column; align-items: center; gap: 0.4rem; padding: 0.9rem 0.6rem; text-decoration: none; }
    .sb-tile img { width: 2.4rem; height: 2.4rem; object-fit: contain; }
    .sb-tile .sb-name { font-size: 0.9rem; text-align: center; line-height: 1.15; }
    .sb-pill { display: inline-block; padding: 0.05rem 0.5rem; border-radius: 999px; font-size: 0.7rem; letter-spacing: 0.05em; text-transform: uppercase; }
    .sb-pill.up    { background: hsla(140, 60%, 55%, 0.18); color: hsl(140, 60%, 65%); }
    .sb-pill.down  { background: hsla(220, 10%, 50%, 0.18); color: hsl(220, 10%, 70%); }
    .sb-pill.error { background: hsla(0, 70%, 60%, 0.22); color: hsl(0, 70%, 70%); }
  </style>
  <div class="sb-grid">
  {{ range .JSON.Array "" }}
    {{ $status := .String "status" }}
    <a class="sb-tile card" href="{{ .String "url" }}" target="_blank"
       data-status="{{ $status }}" data-url="{{ .String "url" }}"
       data-unit="{{ .String "unit" }}" data-name="{{ .String "name" }}"
       onclick="return sbOpen(this, event)">
      <img src="{{ .String "iconUrl" }}" alt="">
      <span class="sb-name">{{ .String "name" }}</span>
      <span class="sb-pill {{ $status }}">{{ $status }}</span>
    </a>
  {{ end }}
  </div>
  <script>
  // Glance renders this custom-api template server-side into the page, so this
  // handler runs in the glance tab (same origin the bridge CORS-allows). A dead
  // service has no useful web page, so intercept the click:
  //   up    → open the web UI (or nothing if the service has no url)
  //   down  → confirm, then POST start to the bridge; never open the dead page
  //   error → running but not answering yet; offer to open anyway
  window.sbOpen = function (el, ev) {
    var d = el.dataset;
    if (d.status === "up") {
      if (d.url) return true;               // running + has web UI → let the link open
      ev.preventDefault(); return false;    // running, no web UI → nothing to open
    }
    ev.preventDefault();
    if (d.status === "error") {
      if (d.url && confirm(d.name + " is running but its page isn't responding yet. Open it anyway?")) {
        window.open(d.url, "_blank");
      }
      return false;
    }
    // down
    if (confirm(d.name + " is not running. Start it now?")) {
      fetch("http://localhost:8770/services/" + encodeURIComponent(d.unit) + "/start", { method: "POST" })
        .then(function (r) { return r.json(); })
        .then(function (j) {
          if (j.ok) { setTimeout(function () { location.reload(); }, 1000); }
          else { alert("Failed to start " + d.name + ": " + (j.stderr || ("rc=" + j.rc))); }
        })
        .catch(function (e) { alert("Bridge error: " + e); });
    }
    return false;
  };
  </script>
''
