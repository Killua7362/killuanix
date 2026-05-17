# claude-kit

Terminal utility (`claude-kit`) for browsing the declarative Claude Code resource catalog (agents, commands, skills, plugins, MCP servers, marketplaces) and managing the per-project **lazy catalog** under `Notes/claude/lazy/`.

Originally a single `claude-kit.nix` file with a ~1200-line `writeShellApplication` body. Split into a directory so each subcommand lives in its own `.sh` file with a real shell LSP and shellcheck.

## Files

| File | Description |
|---|---|
| `default.nix` | Wraps the bash tree as a `writeShellApplication`. Copies `./scripts/` into a nix-store derivation, exports its path as `$CLAUDE_KIT_LIB_DIR`, and `exec bash $CLAUDE_KIT_LIB_DIR/claude-kit.sh`. Also imports the python sidecar venv from `./plan/package.nix` and exports its `bin/claude-kit-plan` as `$CLAUDE_KIT_PLAN_BIN`. Runtime deps: `jq fzf bat coreutils findutils gnused gnugrep yazi`. |
| `plan/` | Python sidecar for `claude-kit plan` — two-stage prompt-to-plan tool built via uv2nix (same lane as `packages/jupyter-env-mcp/`). Layout: `pyproject.toml`, `uv.lock`, `package.nix` (venv builder), `src/claude_kit_plan/{cli,suggest,plan,sdk_helpers,frontmatter}.py`, and `src/claude_kit_plan/prompts/{suggestion,plan-template}.md` shipped as package-data. Reads its prompts via `importlib.resources` so editing `prompts/*.md` requires a rebuild (intentional — the prompts are versioned with the code). The CLI uses the `claude-agent-sdk` python package, which authenticates against your local `~/.claude/.credentials.json` — no API key. |
| `scripts/claude-kit.sh` | Entrypoint. Sets globals (`CLAUDE_DIR`, `KIT_CACHE`, `SOURCES_DIR`, `LAZY_DIR`), sources `lib/*.sh`, prints `usage`, and dispatches `$1` to `cmd/<name>.sh`. |
| `scripts/lib/common.sh` | Shared helpers: `die`, `_list_agents`/`_list_commands`/`_list_skills`, `_resolve_file`. Sourced eagerly from the entrypoint. |
| `scripts/lib/session.sh` | `_render_session` — turns a Claude Code `*.jsonl` conversation log into a markdown preview file (cached by mtime). Used by `cmd/resume.sh`. |
| `scripts/lib/lazy.sh` | Catalog discovery (`_lazy_catalogs`, `_lazy_count`, `_lazy_find`), target-arg parsing (`_lazy_parse_target` → `PARSED_CAT`/`PARSED_TYPE`/`PARSED_NAME`), bundle helpers (`_lazy_bundle_files`, `_lazy_bundle_resolve`, `_lazy_bundle_state`), `_lazy_find_project_config` (walks $PWD upward for `claude-kit.nix`), `_lazy_type_to_key` (CLI type → list key in `claude-kit.nix`), `_project_edit_list` (awk-based mutator that inserts/removes `"<item>"` inside a top-level `<key> = [ … ];` block), `_project_load_sync` (lazy-source `cmd/project.sh`), and `_lazy_help`. Sourced eagerly so any `cmd/lazy/*.sh` file can use them without a second source. |
| `scripts/cmd/list.sh` | `claude-kit list [agents\|commands\|skills\|plugins\|mcp\|marketplaces\|all]`. |
| `scripts/cmd/show.sh` | `claude-kit show <name>` — bat-renders an agent/command/skill markdown. |
| `scripts/cmd/search.sh` | `claude-kit search [query]` — grep filter or fzf picker with live preview. |
| `scripts/cmd/run.sh` | `claude-kit run <command> [args…]` — exec `claude --print "/<command> args"`. |
| `scripts/cmd/plan.sh` | `claude-kit plan` — thin shim that `exec`s `$CLAUDE_KIT_PLAN_BIN` (the python sidecar in `plan/`). |
| `scripts/cmd/resume.sh` | `claude-kit resume [-a] [-f]` — yazi-based session picker over rendered jsonl previews; `cd`'s into the recorded cwd and `exec claude --resume <id>`. |
| `scripts/cmd/clean.sh` | `claude-kit clean [-a]` — prune `*.jsonl` past the 50 most recent per project (plus matching markdown cache). Requires typing `yes` exactly. |
| `scripts/cmd/plugin.sh` | Pass-through to `claude plugin <install\|uninstall\|enable\|disable\|update\|list>`. |
| `scripts/cmd/marketplace.sh` | `claude-kit marketplace <list\|add\|remove>` — direct `jq` edits of `~/.claude/settings.json`. |
| `scripts/cmd/mcp.sh` | Dispatcher: `status\|warm\|forget` manage the local MCP cache (read the Nix-emitted `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json`, warm each wrapper via a JSON-RPC `initialize`, record the warmed nix-store command path under `$XDG_STATE_HOME/mcp-warm/<name>.warmed` to detect `stale` later). Everything else (`list`, `add`, `remove`, `test`, …) passes straight through to `claude mcp …` so the existing Claude Code connect view is preserved. Cache mechanism is at the MCP-protocol layer, so it works uniformly across uvx / npx / uv-run wrappers; uv/npm/uvx download progress streams through the wrapper's stderr to the user TTY. `warm --uncached` skips already-cached entries; `MCP_WARM_TIMEOUT=<sec>` overrides the per-server initialize timeout (default 600). |
| `scripts/cmd/source.sh` | Infers the originating repo (`ruflo`, `wshobson/<plugin>`, `local`) from a resource's filename prefix. |
| `scripts/cmd/ruflo.sh` | Pass-through to the `ruflo` CLI. |
| `scripts/cmd/doctor.sh` | Sanity-checks the install (claude/ruflo on PATH, `~/.claude/{agents,commands,skills}` populated, sources cache linked, lazy dir + upstream catalog). |
| `scripts/cmd/version.sh` | Prints pinned ruflo / wshobson revs. **Update these strings here** when bumping the matching flake inputs (see `../claude-resources/CLAUDE.md`). |
| `scripts/cmd/lazy.sh` | `claude-kit lazy <verb>` dispatcher — sources `cmd/lazy/<verb>.sh` lazily. |
| `scripts/cmd/lazy/ls.sh` | `lazy ls [<catalog>] [--type <kind>]` — list catalogs or contents. |
| `scripts/cmd/lazy/show.sh` | `lazy show <type> <name>` — print catalog item path + rendered markdown. |
| `scripts/cmd/lazy/add.sh` | `lazy add [--imperative] <type> <name>` — if a `claude-kit.nix` is found upward from `$PWD`, edit it in place (insert `"<name>"` into the matching list) and run `project sync --quiet`; otherwise (or with `--imperative`) fall back to the legacy direct path: symlink the catalog item into `./.claude/<type>/`, or flip `enabledPlugins.<name>=true` in `./.claude/settings.local.json` for the `plugin` type. |
| `scripts/cmd/lazy/rm.sh` | `lazy rm [--imperative] <type> <name>` — same dual path as `add`: in a declarative project the entry is removed from `claude-kit.nix` and a re-sync prunes `./.claude/`; with `--imperative` (or outside a den project) the symlink / `settings.local.json` key is deleted directly. |
| `scripts/cmd/lazy/project.sh` | `lazy project [--global]` — list project-scope items; `--global` also dumps the catalog. |
| `scripts/cmd/lazy/new.sh` | `lazy new <name>` — scaffold a new sub-catalog under `Notes/claude/lazy/`. |
| `scripts/cmd/lazy/refresh.sh` | `lazy refresh <name>` — regenerate `<name>/catalog.json` from contents. |
| `scripts/cmd/lazy/doctor.sh` | `lazy doctor` — validate `lazy.json` + every `catalog.json`. |
| `scripts/cmd/lazy/bundle.sh` | `lazy bundle <ls\|show\|add\|rm\|status>` — apply/remove named groups (plugins + MCP + skills/agents/commands) in one shot. In a declarative project (`claude-kit.nix` found upward) every entry the bundle expands to is written into the matching list of `claude-kit.nix`, then a single `project sync` materializes `./.claude/`; outside such a project the legacy direct-write path runs. Reversible state in `./.claude/.lazy-bundles.json` carries a `mode: "declarative"\|"imperative"` marker so `bundle rm` reverses the same way `add` applied. Internal dispatcher (`_lazy_bundle`) routes to the per-verb function. |
| `scripts/cmd/project.sh` | `claude-kit project <sync\|add\|rm\|envrc\|show\|status>` — flake-driven project sync. Reads `./claude-kit.nix` (walks upward from `$PWD`) via `nix-instantiate --eval --strict --json`. `sync` reconciles `./.claude/{skills,agents,commands}/`, `./.claude/settings.local.json` (plugins), and `./.mcp.json` (servers mirrored from `~/.claude.json:.mcpServers`). `add`/`rm` mutate `claude-kit.nix` via `_project_edit_list` (type ∈ `skill\|agent\|command\|plugin\|mcp`) and re-run `sync`. `envrc` prints `export VAR=val` lines for non-empty `envVars` (empty entries inherit from the host shell). Sync state lives at `./.claude/.flake-managed.json` so the next run removes items that were dropped from the schema, while hand-added symlinks survive. Auto-invoked from the `.envrc` den drops on `den new --devshell`. |

## Env-var contract

`default.nix` sets two env vars before exec'ing the entrypoint:

| Env var | Value | Why |
|---|---|---|
| `CLAUDE_KIT_LIB_DIR` | nix-store path of `./scripts/` (after `runCommand` copy) | Used by `claude-kit.sh` to source `lib/*.sh` and `cmd/*.sh`. **Don't** introduce nix interpolation `${...}` inside the `.sh` files — it would break the LSP and the round-trip. |
| `CLAUDE_KIT_PLAN_BIN` | nix-store path to `bin/claude-kit-plan` inside the uv2nix venv built from `./plan/` | Used by `cmd/plan.sh` to exec the python sidecar. Bumping `claude-agent-sdk` is `cd plan/ && uv lock`; bumping the python source is just an edit. |

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

Writes per-project state into `./.claude/{skills,agents,commands,settings.local.json,.lazy-bundles.json,.flake-managed.json}` and `./.mcp.json` when `lazy add` / `lazy bundle add` / `project sync` runs.

## `project sync` flow

`claude-kit project sync` is the declarative path. It reads `./claude-kit.nix` (the schema lives in `den/templates/claude-kit.nix`) — pure attrset:

```nix
{
  envVars  = { APP_HOST = "killua"; DATABASE_URL = ""; };  # "" = inherit
  skills   = [ "code-search" ];
  agents   = [];
  commands = [];
  plugins  = [ "ruflo-core@ruflo" ];
  mcp      = [ "code-index" ];

  # Subtractive + hardening (all materialize into settings.local.json):
  excludeMcp       = [ "mermaid" ];          # adds mcp__mermaid__* deny rule
  excludePlugins   = [ "ruflo-core@ruflo" ]; # enabledPlugins.<slug> = false
  excludeSkills    = [];                     # advisory at project scope — see below
  excludeAgents    = [];                     # advisory
  excludeCommands  = [];                     # advisory

  allowedTools = [ "Bash(rg:*)" ];
  deniedTools  = [ "Bash(curl:*)" "WebFetch" ];

  hooks = null;                              # null = inherit globals
  # hooks = { Stop = [{ hooks = [{ type = "command"; command = "…"; }]; }]; };

  restrictToDirs = null;                     # null = no narrowing
  # restrictToDirs = [ "/home/killua/killuanix/Notes" ];
}
```

Resolution rules:

- **skills/agents/commands** — looked up in the lazy catalog (`_lazy_find`, same lane as `lazy add`). Names not in any catalog are reported and skipped, not fatal.
- **plugins** — written verbatim into `enabledPlugins.<slug>=true` in `./.claude/settings.local.json` (no catalog lookup).
- **mcp** — server stanza resolved by `_lazy_resolve_mcp`, which checks two sources in order: (1) `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` — the full Nix-emitted catalog from `mcp-servers.nix` (includes `optional = true` entries excluded from the global wiring); (2) `~/.claude.json:.mcpServers` — fallback for runtime additions via `claude mcp add`. Resolved stanza copied verbatim into `./.mcp.json`. Names not in either source are skipped with a notice. This means `optional = true` registry entries (currently `claude-flow`, `gitnexus`) only load in projects whose `claude-kit.nix` lists them.
- **envVars** — emitted by `claude-kit project envrc` as `export VAR=val` lines, with **empty values skipped** (so the host shell value, if any, passes through). Hooked from `.envrc` via `eval "$(claude-kit project envrc)"` before the `sync` call.
- **excludeMcp** — each entry becomes a `"mcp__<name>__*"` rule appended into `./.claude/settings.local.json`'s `permissions.deny`. Effective for any globally-loaded MCP server (mermaid, filesystem, …) the project wants disabled. *Also* applied at the MCP boundary when **restrictToDirs** is set and the project declares `"filesystem"` in `mcp = [...]`: the filesystem server's `args` get narrowed to `restrictToDirs` so the upstream server itself refuses paths outside.
- **excludePlugins** — each entry becomes `enabledPlugins."<slug>" = false` in `./.claude/settings.local.json`. Plugins that aren't globally enabled stay alone. Settings precedence means this overrides a `true` in the global `settings.json`.
- **excludeSkills / excludeAgents / excludeCommands** — accepted in the schema for symmetry with the launcher attrs but **advisory** at the project layer. Claude reads these from `~/.claude/{skills,agents,commands}` (the user's HOME), and Claude Code does not currently expose a strict per-project mask for them. The names are recorded in `./.claude/.flake-managed.json` and surfaced by `claude-kit project status` so the intent is documented; enforcement is the user's responsibility (lift the unwanted resource out of `~/.claude/` globally, or add a corresponding `deniedTools` rule).
- **allowedTools / deniedTools** — appended (deduped) into `./.claude/settings.local.json` `permissions.allow` / `permissions.deny`. Pattern syntax matches Claude Code's own permission grammar — `"Bash(curl:*)"`, `"Read(/etc/**)"`, `"WebFetch"`, `"mcp__mermaid__*"`.
- **hooks** — when non-null, written verbatim into `./.claude/settings.local.json` `hooks`. Same shape as `programs.claude-code.settings.hooks`. Claude Code merges project hooks with global hooks at runtime — this is for *additional* hooks scoped to the project. Use `null` to inherit globals only.
- **restrictToDirs** — when non-null: (a) `settings.local.json.permissions.additionalDirectories` is pinned to this list (Claude's built-in Read/Write/Edit honor it); (b) deny patterns for well-known sensitive paths (`~/.ssh`, `~/.gnupg`, `~/.config/sops`, `~/.config/age`, `/etc/**`, `/var/**`, `/root/**`) are appended to `permissions.deny`; (c) if the project's `mcp = [...]` includes `"filesystem"`, the server's `args` in `./.mcp.json` are rewritten from the global `["/home/killua"]` to this list — the upstream MCP server itself rejects paths outside its roots. The `permissions.deny` layer is advisory (Claude obeys but a determined Bash invocation can escape); the MCP narrowing is the strict half.

State at `./.claude/.flake-managed.json` records what `sync` wrote on the prior run, including the **`settingsLocal`** sub-attrset listing every value we appended into `settings.local.json` (allow patterns, deny patterns, excluded plugins, whether we set `additionalDirectories`/`hooks`). The next run **reverts** exactly those entries before applying the current schema — hand-edits to `settings.local.json` that we didn't author are preserved. The bundle path (`.lazy-bundles.json`) is independent — bundles layer on top of `project sync` cleanly.

Globally-enabled skills/MCP (from `programs.claude-code` and `mcp-servers.nix`) stay loaded by default; the additive lists (`skills`/`agents`/`commands`/`plugins`/`mcp`) layer on top, and the subtractive attrs (`excludeMcp`/`excludePlugins`/etc.) + permissions/hooks opt out of or harden the project's view.

### CLI mutators auto-route through `claude-kit.nix`

When `_lazy_find_project_config` finds a `claude-kit.nix` above `$PWD`, every mutator (`lazy add`, `lazy rm`, `lazy bundle add`, `lazy bundle rm`) edits the nix file in place via `_project_edit_list` and then calls `_project_sync --quiet` — `claude-kit.nix` is the single source of truth, the CLI is sugar over editing it. The edit is awk-based and expects the canonical multi-line list format (one entry per line, closing `];` on its own line). Pass `--imperative` to `lazy add`/`lazy rm` to bypass detection and use the legacy direct-symlink path (useful for one-off ad-hoc additions outside the declared set).

Equivalent declarative-only entry points:

```
claude-kit project add <type> <name>     # type: skill|agent|command|plugin|mcp
claude-kit project rm  <type> <name>
```

These never fall back to imperative — they `die` if no `claude-kit.nix` is found.

`_project_edit_list` exit codes:

| rc | Meaning |
|---|---|
| 0  | Edited; file rewritten via `mktemp` + `mv -f`. |
| 2  | List key not present in the file. |
| 3  | List opens and closes on the same line — needs reformat (one entry per line). |
| 4  | `add`: item already in the block (no-op). |
| 5  | `add`: closing `];` not found (malformed file). |
| 6  | `rm`: item not in the block (no-op). |
