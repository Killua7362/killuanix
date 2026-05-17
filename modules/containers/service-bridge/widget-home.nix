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
    <a class="sb-tile card" href="{{ .String "url" }}" target="_blank">
      <img src="{{ .String "iconUrl" }}" alt="">
      <span class="sb-name">{{ .String "name" }}</span>
      <span class="sb-pill {{ $status }}">{{ $status }}</span>
    </a>
  {{ end }}
  </div>
''
