# claude-resources

Builds **one lazy sub-catalog per upstream source** under `Notes/claude/lazy/<source>/`. Sources currently wired: `ruflo`, `wshobson` (= `inputs.wshobson-agents`), `anthropics-skills`, `gstack` (= `inputs.gstack`, garrytan/gstack). Each sub-catalog ships its own `catalog.json` so `claude-kit lazy …` can opt resources in per-project.

Was originally a single merged `upstream/` catalog — split so adding a new flake input means a new sibling folder rather than another row mixed into one tree.

## Files

| File | Description |
|---|---|
| `default.nix` | Wires `inputs.{ruflo,wshobson-agents,anthropics-skills}` into per-source flat dirs + per-source `mkCatalog` calls + (for ruflo only) a bundles dir. Each `runCommand` reads its bash body via `builtins.readFile ./build/*.sh` and passes nix-injected store paths through env vars on the derivation's attrset. The activation block at the bottom lays down `Notes/claude/lazy/{ruflo,wshobson,anthropics-skills}/` and removes the legacy `Notes/claude/lazy/upstream/` directory if a previous generation left one behind. |
| `build/flat-ruflo-markdown.sh` | Used twice (`agents`, `commands`) — flattens `$RUFLO/.claude/$KIND/**/*.md` into `$out`. Nested subdirs collapse via `slash → --`. No outer prefix (catalog name already disambiguates). |
| `build/flat-wshobson-markdown.sh` | Used twice (`agents`, `commands`) — flattens `$WSHOBSON/plugins/<plugin>/$KIND/*.md` into `$out/<plugin>--<basename>` so distinct plugins don't collide inside one catalog. |
| `build/flat-ruflo-skills.sh` | Copies `$RUFLO/.claude/skills/<name>/` → `$out/<name>/`, preserving `SKILL.md` + assets. |
| `build/flat-wshobson-skills.sh` | Copies `$WSHOBSON/plugins/<plugin>/skills/<name>/` → `$out/<plugin>--<name>/`. |
| `build/catalog.sh` | **Shared, parameterised by `$NAME`**. Walks `$SKILLS_DIR/*/`, `$AGENTS_DIR/*.md`, `$COMMANDS_DIR/*.md` (any of which may be unset) and emits `$out/catalog.json`. Paths in the emitted JSON are absolute nix-store paths so `claude-kit lazy add` symlinks straight to them. |
| `build/ruflo-bundles.sh` | Emits the static `$out/ruflo.json` bundle manifest (the 8-plugin ruflo stack). Lives under `Notes/claude/lazy/ruflo/bundles/` after activation. |

## Env-var contract

Each `.sh` reads its inputs from env vars set in the corresponding `runCommand` attrset in `default.nix`. Adding a new input means: declare it as an attribute on the `runCommand`'s second arg, then reference it via `$VAR` in the script. **Don't** introduce nix interpolation `${...}` inside the `.sh` files — it would break the LSP and the round-trip.

| Script | Required env vars |
|---|---|
| `flat-ruflo-markdown.sh` | `KIND`, `RUFLO` |
| `flat-wshobson-markdown.sh` | `KIND`, `WSHOBSON` |
| `flat-ruflo-skills.sh` | `RUFLO` |
| `flat-wshobson-skills.sh` | `WSHOBSON` |
| `catalog.sh` | `NAME`, `SKILLS_DIR`, `AGENTS_DIR`, `COMMANDS_DIR` (any may be empty; jq on `nativeBuildInputs`) |
| `ruflo-bundles.sh` | none (+ `jq` on `nativeBuildInputs`) |

`$out` is always set by Nix; never set it manually.

## Adding a new upstream source

1. Add the flake input in the repo root `flake.nix` (e.g. `inputs.foo`).
2. In `default.nix`, alongside `ruflo` / `wshobson`:
   - Optionally build per-source flat dirs (or point at the input's tree directly if its layout already matches the catalog shape — e.g. `anthropics-skills` skips the flat step and just uses `${anthropicsSkills}/skills`).
   - Add a `fooCatalog = mkCatalog "foo" { skillsDir = …; agentsDir = …; commandsDir = …; };` block.
   - Append a `ln -sfn "${fooCatalog}/catalog.json" "$_lazy/foo/catalog.json"` line to the activation script (and `mkdir -p "$_lazy/foo"`).
3. Add a row in `Notes/claude/lazy/lazy.json` so the description shows up in `claude-kit lazy ls`.

The next `scripts/nix_switch` materialises `Notes/claude/lazy/foo/` and `claude-kit lazy ls` picks it up via subdir auto-discovery — no other code changes needed.

## Bumping an existing upstream source

1. `nix flake lock --update-input <ruflo|wshobson-agents|anthropics-skills>`
2. If the ruflo npm CLI moved, also bump `rufloVersion` in `../ruflo-cli.nix` and the `rev:` line in `../claude-kit/`.
3. The next `nix_switch` regenerates the affected `catalog.json` automatically.

## Naming inside catalogs

Now that each source has its own catalog, the outer `ruflo--` / `wshobson--` prefixes are dropped. The per-source structure still encodes any necessary disambiguation:

| Source | Naming pattern in `catalog.json` |
|---|---|
| `ruflo` | `<subpath-with-slashes-as-dashes>` (was `ruflo--<…>`) |
| `wshobson` | `<plugin>--<basename>` (was `wshobson--<plugin>--<…>`) |
| `anthropics-skills` | upstream name unchanged (already flat) |
| `gstack` | single `gstack` skill entry — the whole upstream tree is wrapped under `skills/gstack/` because sub-skills reference `~/.claude/skills/gstack/bin/...` paths internally |

## Integration

Imported by `../default.nix` as `./claude-resources` (resolves to this `default.nix`). Consumed by:

- `~/.cache/claude-kit/sources/{ruflo,wshobson,anthropics-skills}-catalog.link` (plus the per-source flat-dir links) — read-only symlinks for `claude-kit` to walk without globbing the store.
- `Notes/claude/lazy/{ruflo,wshobson,anthropics-skills}/catalog.json` and `Notes/claude/lazy/ruflo/bundles/` — set up by `home.activation.lazyUpstreamCatalogSymlink`. The same activation block also nukes a legacy `Notes/claude/lazy/upstream/` directory if present.
