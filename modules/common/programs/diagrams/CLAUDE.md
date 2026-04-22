# Diagrams Module

Home Manager module for diagram authoring tooling — Excalidraw and Mermaid — backed by local containers and wired into the desktop via shell launchers, XDG desktop entries, and a shared-mime-info drop-in so `.mmd` / `.mermaid` files route through the live editor.

## Files

| File | Description |
|---|---|
| `default.nix` | Entry point; imports `./excalidraw.nix` and `./mermaid.nix`. On Linux only, installs a `diagramsMimeInfo` package that drops a shared-mime-info XML under `share/mime/packages/diagrams.xml` registering `text/vnd.mermaid` (sub-class of `text/plain`, globs `*.mmd` and `*.mermaid`). `xdg.mime.enable` (set via `modules/cross-platform/default.nix`) triggers `update-mime-database` automatically on activation. |
| `excalidraw.nix` | Linux-only. Defines the `excalidraw` shell launcher and a `Graphics` / `Development` XDG desktop entry. |
| `mermaid.nix` | Cross-platform `pkgs.mermaid-cli` (`mmdc`) for offline `.mmd` → svg/png/pdf rendering. Linux-only `mermaid-live` shell launcher + desktop entry on top. Exports `home.sessionVariables.MERMAID_CLI = "${pkgs.mermaid-cli}/bin/mmdc"` as a deterministic path for neovim renderers and scripts. |

## Excalidraw Launcher (excalidraw.nix)

The `excalidraw` shell wrapper opens `http://localhost:8899` — served by the container in `modules/containers/excalidraw.nix` (NixOS only) — preferring `chromium --app=<url>`, then `google-chrome-stable --app=<url>`, then falling back to `xdg-open`. App-mode gives Excalidraw its own window without browser chrome. The desktop entry (`Excalidraw`, categories `Graphics;Development;`) drops into the app launcher.

**Note**: stock Excalidraw has no URL-scene loader, so `.excalidraw` files are NOT routed through xdg-open — opening one that way falls through to the JSON handler (neovim). Use Excalidraw's in-app "Open" button to load files.

## Mermaid Live Launcher (mermaid.nix)

The `mermaid-live` shell wrapper targets `http://localhost:8898` — served by `modules/containers/mermaid-live.nix`. When invoked with a readable file argument (the desktop entry uses `Exec=... %f` and declares `MimeType=text/vnd.mermaid;`), a Python one-liner reads the source on stdin, zlib-deflates it at level 9, and base64url-encodes the result (stripping `=` padding) into a `pako:` URL fragment. The final target becomes `http://localhost:8898/edit#pako:<encoded>`, matching the mermaid.live share-URL format so the editor opens with the diagram preloaded. Browser dispatch is the same chromium → google-chrome-stable → xdg-open chain used by Excalidraw.

## MIME Wiring (default.nix)

`diagramsMimeInfo` is a `pkgs.writeTextDir` derivation producing `share/mime/packages/diagrams.xml`. When Home Manager installs it into `~/.nix-profile/share/mime/packages/`, the system mime cache picks up `text/vnd.mermaid` with globs `*.mmd` / `*.mermaid` and the `text/plain` sub-class relationship. Paired with the `mimeTypes = ["text/vnd.mermaid"];` field on the `mermaid-live` desktop entry, `xdg-open foo.mmd` and file-manager double-clicks open the container-backed editor with the diagram preloaded.

## Container Dependency

Both launchers expect locally-running containers:

- `modules/containers/excalidraw.nix` → `:8899`
- `modules/containers/mermaid-live.nix` → `:8898`

These containers are only provisioned on NixOS (imported from the respective `nixosConfigurations`). On Arch (`archnix`) and Darwin (`macnix`) the wrappers install and the desktop entries register, but the target ports will be unreachable until the user brings up their own instances (e.g. via podman/docker-compose against the same images). The `mmdc` CLI works everywhere since it's a pure-Nix package with no container backing.

## MCP Integration

`../dev/claude.nix` consumes `modules/common/mcp-servers.nix`, which registers two MCP servers that pair with these editors:

- `mermaid` — `@peng-shawn/mermaid-mcp-server` (via `npxDirect`). Renders Mermaid source to PNG/SVG via puppeteer; the `PUPPETEER_EXECUTABLE_PATH` override in `claude.nix` points it at `${pkgs.chromium}/bin/chromium`.
- `excalidraw` — `mcp-excalidraw-server` (via `npxDirect`). Creates and edits `.excalidraw` JSON scenes; exposes an optional WebSocket canvas server on `PORT=3031` to avoid colliding with anything on :3000.

Local skills under `../dev/skills/` (`mermaid-diagrams`, `excalidraw-sketches`) are auto-collected into `programs.claude-code.skills` by `claude.nix`'s `skillRoots` walker, so Claude Code can generate diagrams that open directly in the local editors configured here.

## Integration

`default.nix` is imported by `modules/common/programs.nix`, which is pulled into `modules/cross-platform/default.nix` for all platforms. The `lib.optionals pkgs.stdenv.isLinux` guards on the launcher packages, desktop entries, and MIME drop-in mean macOS gets only `mmdc`, while all Linux platforms (NixOS killua, handheld, archnix) get the full editor wiring.
