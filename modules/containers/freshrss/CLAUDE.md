# FreshRSS Container Module

Self-hosted RSS aggregator (Google Reader + Fever API compatible) reachable at
http://localhost:8083. Single quadlet, SQLite-backed, with **declarative
extensions / per-user prefs / OPML import** layered on top of the basic
container.

## Files

| File | Description |
|---|---|
| `default.nix` | Quadlet container + `freshrss-env.service` (sops → env-file). Bind-mounts the extensions bundle and sets `THIRDPARTY_EXTENSIONS_PATH`. |
| `extensions.nix` | `symlinkJoin`s selected `pkgs.freshrss-extensions.*` into a single dir. Exposes `services.freshrssExtensions.{bundle,enabledIds}` so `bootstrap.nix` can auto-tick them. |
| `bootstrap.nix` | Three oneshots: `freshrss-bootstrap-create-user` (idempotent admin creation via `cli/create-user.php` when the user dir is absent — covers the image-entrypoint race where only the `_` placeholder gets seeded; also patches global `data/config.php` to set `default_user` + `api_enabled = true` so the Greader/Fever endpoints don't 503), `freshrss-bootstrap-user-cfg` (hash-gated merge of nix-declared prefs into `data/users/<user>/config.php`), and `freshrss-bootstrap-api-pw` (always-run re-apply of the API password from sops). |
| `opml.nix` | Drop-folder + optional-sops OPML import via `cli/import-for-user.php`. Drop `*.opml` / `*.xml` into `~/killuanix/Notes/freshrss-opml/` (synced across hosts via obsidian-git); systemd.path triggers an idempotent import. Content-hash sentinels under `/var/lib/freshrss/state/opml-<sha>.imported` skip already-imported files (per-host, so each box converges independently). Daily timer + OnBootSec=2min catch missed events. Set `cfg.useSops = true` to also pull from the `freshrss_opml` sops scalar. |

## Cadence

| Service | When it runs | Idempotent? |
|---|---|---|
| `freshrss.service` | Always (autoStart) | Image entrypoint installs once on empty volume, then no-ops. |
| `freshrss-env.service` | Before `freshrss.service` | Yes — overwrites `/run/freshrss/env` every boot. |
| `freshrss-bootstrap-create-user.service` | After `freshrss.service`, before the other bootstrap oneshots | Yes — skips when `data/users/<user>/config.php` already exists. |
| `freshrss-bootstrap-user-cfg.service` | After `freshrss-bootstrap-create-user.service`, only when the rendered overrides hash differs from the sentinel | Yes — `array_replace_recursive` preserves auth-bearing fields. |
| `freshrss-bootstrap-api-pw.service` | After `freshrss.service`, every boot | Yes — setting the API password to the same value is a no-op. |
| `freshrss-import.service` | On any file change in `~/killuanix/Notes/freshrss-opml/` (path unit), boot+2min, and daily | Yes — feeds deduped by URL, entries by GUID. Content-hash sentinels under `/var/lib/freshrss/state/` skip already-imported files. |

## Sentinel layout

```
/var/lib/freshrss/state/
  .user-cfg-applied              # SHA-256 of the last nix-rendered overrides PHP
  opml-<sha256>.imported         # one per imported OPML file (drop-folder + sops)
```

The user-cfg sentinel gates a single oneshot. The OPML sentinels are one per
file-content hash (a `touch`-only marker, content doesn't matter). The
API-password service is **always-run** by design — it targets an idempotent
CLI command so re-running has no cost.

## How to toggle features

| Feature | File | Toggle |
|---|---|---|
| Enable a packaged extension | `extensions.nix` | Uncomment its line in `enabledExtensions`. Bootstrap auto-ticks it (via `enabledIds`). |
| Enable a community (non-nixpkgs) extension | `extensions.nix` | Uncomment a `buildFreshRssExtension { ... }` block; fill `src` + `hash`. Then add its `xExtension-<Name>` id to `extensions_enabled` in `bootstrap.nix`. |
| Change theme / view / sort / archiving | `bootstrap.nix` | Edit `userConfig.theme` etc. Hash changes → next switch re-applies. |
| Enable sharing destinations | `bootstrap.nix` | Uncomment the `sharing = [ ... ];` block, fill in URLs. |
| Enable saved-search sidebar entries | `bootstrap.nix` | Uncomment `queries = [ ... ];`. |
| Pre-populate feed list from OPML | drop file into `~/killuanix/Notes/freshrss-opml/` | `cp ~/Downloads/feeds.opml ~/killuanix/Notes/freshrss-opml/`. Import fires within seconds. File stays as-is; sentinel under `/var/lib/freshrss/state/opml-<sha>.imported` records that the content was imported. Editing the file → new hash → re-imports. Commit the file in the Notes git repo to sync to the other host. |
| Use sops-encrypted OPML instead/in addition | `opml.nix` + sops | Flip `cfg.useSops = true`, add `freshrss_opml: \|` (multi-line OPML) to `secrets/personal.yaml`. opml.nix conditionally declares the sops key when this is on. |

## Rotating the API password (sops → running container)

The image entrypoint only honors `ADMIN_API_PASSWORD` on first boot. Rotating
the sops secret alone won't propagate. The workflow:

1. `sops secrets/personal.yaml` — edit `freshrss_admin_api_password`.
2. `scripts/nix_switch` — restarts `freshrss-env.service`, and
   `freshrss-bootstrap-api-pw.service` then calls
   `cli/update-user.php --user killua --api-password "$ADMIN_API_PASSWORD"`
   inside the container, which **does** rotate the running credential.
3. RSSGuard / NewsFlash / Reeder: update the saved password the next time you
   open the client. The Google Reader endpoint is still
   `http://localhost:8083/api/greader.php`.

## Bootstrap failure modes

- **`per-user config.php missing`** — historically caused by the image
  entrypoint racing the env-file and seeding only the `_` placeholder.
  `freshrss-bootstrap-create-user.service` now creates the admin via
  `cli/create-user.php` + `update-user.php --is-admin yes` when the user dir
  is absent, so this should no longer hit. If it still does, the create-user
  service likely failed — check its journal. Note the container's web server
  runs as `www-data` (NOT `apache`); both create-user and api-pw `su` into
  `www-data`.
- **Hash sentinel out of sync after a manual UI edit** — the UI edits get
  clobbered on the next rebuild that bumps the overrides hash. This is by
  design (declarative-first contract, same as the cronicle event-toggle).
  If you want to keep a UI-set value, mirror it into `userConfig` in
  `bootstrap.nix`.
- **`&amp;` literal in stored feed URL** — FreshRSS's OPML importer stores
  `xmlUrl="..."` values verbatim, without decoding XML entities. URLs that
  legitimately contain `&` (rss-bridge query strings: `?action=display&bridge=...&format=Atom`)
  must be encoded as `&amp;` in OPML to keep the file valid XML, but get
  stored with the literal `&amp;` and the fetcher errors. `opml.nix`'s
  `import_one()` pre-decodes `&amp;` → `&` inside `xmlUrl="..."` values
  before the OPML reaches the container (looped sed, idempotent). If you
  introduce other entities in URLs (`&apos;`, `&quot;`, `&lt;`, `&gt;`),
  extend that loop.
- **Adding extension on disk without ticking** — extension files appear under
  `/var/www/FreshRSS/extensions/nix/` but FreshRSS ignores them until the
  user-config has `extensions_enabled[<id>] = true`. `bootstrap.nix` derives
  that list automatically from `services.freshrssExtensions.enabledIds`, so
  the two stay in lockstep as long as you only enable extensions via
  `extensions.nix` (and not by hand-editing `bootstrap.nix`'s
  `extensions_enabled` block — that block is a derived value, don't fork it).

## Integration

`modules/containers/default.nix` imports `./freshrss`, which is currently
used on `chrollo` and `killua` via the system-level container stack. Sops
keys live in `modules/common/sops-system.nix` (the container reads
`freshrss_admin_password` + `freshrss_admin_api_password`); the API password
is **also** declared on the HM side in `modules/common/sops.nix` so the
user-space `freshrss` MCP server (under
`modules/common/programs/dev/ai/freshrss-mcp/`) can read it. The desktop
reader (RSSGuard) is wired separately under
`modules/common/programs/rss/`. The Claude Code MCP integration —
`claude-news` launcher + `freshrss` MCP server (Greader API client) — lives
under `modules/common/programs/dev/ai/freshrss-mcp/` and
`modules/common/programs/dev/ai/news/commands/`.
