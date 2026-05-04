# claude-resources

Builds the **upstream** Claude Code resource catalog from external flake inputs (`ruflo`, `wshobson-agents`, `anthropics-skills`) into a flat tree on disk plus a `catalog.json` + `bundles/` that `claude-kit lazy …` reads per-project.

Originally a single `claude-resources.nix` file with four embedded `runCommand` bash bodies. Split into a directory so each build script lives in its own `.sh` file with a real shell LSP and shellcheck.

## Files

| File | Description |
|---|---|
| `default.nix` | Wires `inputs.{ruflo,wshobson-agents,anthropics-skills}` into four `runCommand` derivations. Each `runCommand` reads its bash body via `builtins.readFile ./build/*.sh` and passes nix-injected store paths through env vars on the derivation's attrset. |
| `build/flat-markdown.sh` | Used twice (once for `agents`, once for `commands`) — flattens `$RUFLO/.claude/$KIND/**/*.md` and `$WSHOBSON/plugins/*/$KIND/*.md` into `$out` with collision-free names. |
| `build/flat-skills.sh` | Flattens `$RUFLO/.claude/skills/*/` and `$WSHOBSON/plugins/*/skills/*/` into `$out/{ruflo--<name>,wshobson--<plugin>--<name>}/` directories preserving `SKILL.md` and assets. |
| `build/upstream-catalog.sh` | Walks the three flat dirs (`$SKILLS_DIR`, `$AGENTS_DIR`, `$COMMANDS_DIR`) and `$ANTHROPICS_SKILLS/skills/`, emits a single `$out/catalog.json` with `{name, path}` arrays per resource type. Paths are absolute nix-store paths so symlink-based per-project add works without copying. |
| `build/upstream-bundles.sh` | Emits the static `$out/ruflo.json` bundle manifest (the 8-plugin ruflo stack). No dynamic inputs. |

## Env-var contract

Each `.sh` reads its inputs from env vars set in the corresponding `runCommand` attrset in `default.nix`. Adding a new input means: declare it as an attribute on the `runCommand`'s second arg, then reference it via `$VAR` in the script. **Don't** introduce nix interpolation `${...}` inside the `.sh` files — it would break the LSP and the round-trip.

| Script | Required env vars |
|---|---|
| `flat-markdown.sh` | `KIND`, `RUFLO`, `WSHOBSON` |
| `flat-skills.sh` | `RUFLO`, `WSHOBSON` |
| `upstream-catalog.sh` | `SKILLS_DIR`, `AGENTS_DIR`, `COMMANDS_DIR`, `ANTHROPICS_SKILLS` (+ `jq` on `nativeBuildInputs`) |
| `upstream-bundles.sh` | none (+ `jq` on `nativeBuildInputs`) |

`$out` is always set by Nix; never set it manually.

## Updating an upstream bundle

Source bundles are pinned in the root `flake.nix`. To bump:

1. `nix flake lock --update-input <ruflo|wshobson-agents|anthropics-skills>`
2. If the ruflo npm CLI moved, also bump `rufloVersion` in `../ruflo-cli.nix` and the `rev:` line in `../claude-kit/`.
3. The next `nix_switch` regenerates `Notes/claude/lazy/upstream/catalog.json` automatically.

## Integration

Imported by `../default.nix` as `./claude-resources` (resolves to this `default.nix`). Consumed by:

- `~/.cache/claude-kit/sources/{agents,commands,skills,upstream-catalog,upstream-bundles}.link` — read-only symlinks for `claude-kit` to walk without globbing the store.
- `Notes/claude/lazy/upstream/catalog.json` + `Notes/claude/lazy/upstream/bundles/` — set up by `home.activation.lazyUpstreamCatalogSymlink`.
