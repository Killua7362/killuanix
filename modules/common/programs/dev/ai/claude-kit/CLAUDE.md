# claude-kit

Terminal utility (`claude-kit`) for browsing the declarative Claude Code resource catalog (agents, commands, skills, plugins, MCP servers, marketplaces) and managing the per-project **lazy catalog** under `Notes/claude/lazy/`.

Originally a single `claude-kit.nix` file with a ~1200-line `writeShellApplication` body. Split into a directory so each subcommand lives in its own `.sh` file with a real shell LSP and shellcheck.

## Files

| File | Description |
|---|---|
| `default.nix` | Wraps the bash tree as a `writeShellApplication`. Copies `./scripts/` into a nix-store derivation, exports its path as `$CLAUDE_KIT_LIB_DIR`, and `exec bash $CLAUDE_KIT_LIB_DIR/claude-kit.sh`. Runtime deps: `jq fzf bat coreutils findutils gnused gnugrep yazi`. |
| `scripts/claude-kit.sh` | Entrypoint. Sets globals (`CLAUDE_DIR`, `KIT_CACHE`, `SOURCES_DIR`, `LAZY_DIR`), sources `lib/*.sh`, prints `usage`, and dispatches `$1` to `cmd/<name>.sh`. |
| `scripts/lib/common.sh` | Shared helpers: `die`, `_list_agents`/`_list_commands`/`_list_skills`, `_resolve_file`. Sourced eagerly from the entrypoint. |
| `scripts/lib/session.sh` | `_render_session` — turns a Claude Code `*.jsonl` conversation log into a markdown preview file (cached by mtime). Used by `cmd/resume.sh`. |
| `scripts/lib/lazy.sh` | Catalog discovery (`_lazy_catalogs`, `_lazy_count`, `_lazy_find`), target-arg parsing (`_lazy_parse_target` → `PARSED_CAT`/`PARSED_TYPE`/`PARSED_NAME`), bundle helpers (`_lazy_bundle_files`, `_lazy_bundle_resolve`, `_lazy_bundle_state`), and `_lazy_help`. Sourced eagerly so any `cmd/lazy/*.sh` file can use them without a second source. |
| `scripts/cmd/list.sh` | `claude-kit list [agents\|commands\|skills\|plugins\|mcp\|marketplaces\|all]`. |
| `scripts/cmd/show.sh` | `claude-kit show <name>` — bat-renders an agent/command/skill markdown. |
| `scripts/cmd/search.sh` | `claude-kit search [query]` — grep filter or fzf picker with live preview. |
| `scripts/cmd/run.sh` | `claude-kit run <command> [args…]` — exec `claude --print "/<command> args"`. |
| `scripts/cmd/resume.sh` | `claude-kit resume [-a] [-f]` — yazi-based session picker over rendered jsonl previews; `cd`'s into the recorded cwd and `exec claude --resume <id>`. |
| `scripts/cmd/clean.sh` | `claude-kit clean [-a]` — prune `*.jsonl` past the 50 most recent per project (plus matching markdown cache). Requires typing `yes` exactly. |
| `scripts/cmd/plugin.sh` | Pass-through to `claude plugin <install\|uninstall\|enable\|disable\|update\|list>`. |
| `scripts/cmd/marketplace.sh` | `claude-kit marketplace <list\|add\|remove>` — direct `jq` edits of `~/.claude/settings.json`. |
| `scripts/cmd/mcp.sh` | Pass-through to `claude mcp …`. |
| `scripts/cmd/source.sh` | Infers the originating repo (`ruflo`, `wshobson/<plugin>`, `local`) from a resource's filename prefix. |
| `scripts/cmd/ruflo.sh` | Pass-through to the `ruflo` CLI. |
| `scripts/cmd/doctor.sh` | Sanity-checks the install (claude/ruflo on PATH, `~/.claude/{agents,commands,skills}` populated, sources cache linked, lazy dir + upstream catalog). |
| `scripts/cmd/version.sh` | Prints pinned ruflo / wshobson revs. **Update these strings here** when bumping the matching flake inputs (see `../claude-resources/CLAUDE.md`). |
| `scripts/cmd/lazy.sh` | `claude-kit lazy <verb>` dispatcher — sources `cmd/lazy/<verb>.sh` lazily. |
| `scripts/cmd/lazy/ls.sh` | `lazy ls [<catalog>] [--type <kind>]` — list catalogs or contents. |
| `scripts/cmd/lazy/show.sh` | `lazy show <type> <name>` — print catalog item path + rendered markdown. |
| `scripts/cmd/lazy/add.sh` | `lazy add <type> <name>` — symlink catalog item into `./.claude/<type>/`, or flip `enabledPlugins.<name>=true` in `./.claude/settings.local.json` for the `plugin` type. |
| `scripts/cmd/lazy/rm.sh` | `lazy rm <type> <name>` — reverse of `add`. |
| `scripts/cmd/lazy/project.sh` | `lazy project [--global]` — list project-scope items; `--global` also dumps the catalog. |
| `scripts/cmd/lazy/new.sh` | `lazy new <name>` — scaffold a new sub-catalog under `Notes/claude/lazy/`. |
| `scripts/cmd/lazy/refresh.sh` | `lazy refresh <name>` — regenerate `<name>/catalog.json` from contents. |
| `scripts/cmd/lazy/doctor.sh` | `lazy doctor` — validate `lazy.json` + every `catalog.json`. |
| `scripts/cmd/lazy/bundle.sh` | `lazy bundle <ls\|show\|add\|rm\|status>` — apply/remove named groups (plugins + MCP + symlinks) in one shot, with reversible state in `./.claude/.lazy-bundles.json`. Internal dispatcher (`_lazy_bundle`) routes to the per-verb function. |

## Env-var contract

`default.nix` sets exactly one env var before exec'ing the entrypoint:

| Env var | Value | Why |
|---|---|---|
| `CLAUDE_KIT_LIB_DIR` | nix-store path of `./scripts/` (after `runCommand` copy) | Used by `claude-kit.sh` to source `lib/*.sh` and `cmd/*.sh`. **Don't** introduce nix interpolation `${...}` inside the `.sh` files — it would break the LSP and the round-trip. |

The bash bodies use `$HOME`, `$XDG_CACHE_HOME`, `$PWD`, `$YAZI_CONFIG_HOME` straight from the runtime environment; pinned strings (ruflo/wshobson revs) are hardcoded in `cmd/version.sh`.

## Sourcing convention

The entrypoint eagerly sources three lib files: `common.sh`, `session.sh`, `lazy.sh`. Per-subcommand scripts under `cmd/` are sourced lazily — only the dispatched verb is loaded per invocation. The `lazy` and `lazy bundle` dispatchers do the same: each sub-verb is its own file, sourced on demand. A few inter-script sources exist where one cmd file calls into another (e.g. `lazy/bundle.sh` sources `lazy/add.sh` to apply per-item symlinks).

## Shellcheck disables

The original module set `excludeShellChecks = ["SC2088" "SC2016"]` file-wide. Now each disable lives on the specific lines that need it: `# shellcheck disable=SC2088` on the three `~/.claude/...` display strings inside `cmd/doctor.sh:check`, and `# shellcheck disable=SC2016` on the markdown-code-span `printf` formats inside `lib/session.sh:_render_session`.

## Integration

Imported by `../default.nix` as `./claude-kit` (resolves to this `default.nix`). Reads:

- `~/.claude/{agents,commands,skills,settings.json,projects,…}` — Claude Code's own state.
- `~/.cache/claude-kit/sources/*.link` — read-only symlinks emitted by `../claude-resources/` so the script can walk the upstream tree without globbing the nix store.
- `~/.cache/claude-kit/sessions/<encoded-cwd>/<sid>.md` — its own jsonl→markdown render cache (mtime-keyed; pruned daily by `modules/containers/cronicle/events/claude-kit-prune.nix`).
- `Notes/claude/lazy/<catalog>/catalog.json` and `Notes/claude/lazy/<catalog>/bundles/*.json` — the per-project lazy catalog (set up by `../claude-resources/` for `upstream`, hand-curated otherwise).

Writes per-project state into `./.claude/{skills,agents,commands,settings.local.json,.lazy-bundles.json}` and `./.mcp.json` when `lazy add` / `lazy bundle add` runs.
