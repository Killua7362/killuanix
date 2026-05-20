# claude-launchers

Sister wrappers around `claude` that boot Claude Code with curated extra resources layered on top of the global config — and **isolated** from project-level Claude config in cwd ancestors. Plain `claude` keeps the global skill set + sees project `.claude/`/`.mcp.json`/`CLAUDE.md`; each launcher (`claude-algo`, `claude-news`, `claude-discover`, …) adds curated extras and blocks the project-level discovery walk entirely.

## Files

| File | Description |
|---|---|
| `default.nix` | HM module. Defines `mkClaudeLauncher` (the function that builds a `writeShellApplication` for a launcher) and auto-discovers every sibling `*.nix` (except itself) as a launcher definition. To add a launcher, drop a new file in this dir — no edit here. Exports `notesCmd` (resolves a name to `Notes/claude/lazy/personal/commands/<name>.md`) for launcher files to use. |
| `claude-algo.nix` | `claude-algo` — adds the `algo-sensei` skill (`inputs.algo-sensei`) on top of the global config. `inheritGlobal = true`, everything else inherited. Reference launcher file showing every supported attr with comments. |
| `claude-news.nix` | `claude-news` — sandbox launcher scoped to FreshRSS news reading + Q&A. `inheritGlobal = false`, lean MCP set (`freshrss`/`fetch`/`basic-memory`), `restrictToDirs = [Notes]`. Reference for how to build a fully-isolated launcher. |
| `claude-discover.nix` | `claude-discover` — registry-discovery launcher for finding MCPs / skills / plugins / subagents matching a use-case across multiple online registries (official MCP registry, Glama, PulseMCP, anthropics/skills, wshobson/agents, davila7/claude-code-templates, ruvnet/ruflo, anthropics/claude-plugins-official, VoltAgent/awesome-claude-code-subagents). `inheritGlobal = false`, MCP set `[ "kindly-web-search" "fetch" "basic-memory" ]`, `effort = "high"`. Loads the `discover-resource` skill from `Notes/claude/lazy/personal/skills/` and ships `/find <use-case>` as the entrypoint. |
| `CLAUDE.md` | This file. |

## Mechanism

1. **CLAUDE_CONFIG_DIR** points at `$XDG_STATE_HOME/claude-launchers/<stateName>/`. That dir mirrors every top-level entry of `~/.claude/` as a symlink (auth, projects, …) so the alternate config is functionally identical to the global one. Without this, Claude would force re-auth and drop every MCP server.
2. **skills / agents / commands** under the state dir are rebuilt on every launch as fresh subdirs. With `inheritGlobal = true`, upstream entries from `~/.claude/{skills,agents,commands}/` are mirrored (minus per-launcher `excludeSkills`/`excludeAgents`/`excludeCommands`) and per-launcher declared extras layer on top. With `inheritGlobal = false`, only the per-launcher extras are wired.
3. **settings.json** is written as a **real writable file** (jq-edited copy of `~/.claude/settings.json` from the nix store) so the `overlayClaude` wrapper's settings-rewrite guard (`if [ -L … ] || [ ! -w … ]` at `claude.nix:223`) is bypassed and our jq edits (model, effort, plugins, allowedTools/deniedTools, hooks, additionalDirectories) survive into the running session.
4. **MCPs** go into a per-launcher inline plugin at `$state_dir/plugin/.mcp.json`. Claude reads MCPs from plugin `.mcp.json` files, not from `settings.json.mcpServers`. The launcher exec's `<finalPackage>/bin/.claude-wrapped` directly with `--plugin-dir $state_dir/plugin`, bypassing the global HM `claude` wrapper that would otherwise force-inject the HM-built plugin carrying every `programs.claude-code.mcpServers` entry. Composition rule: `inheritGlobal=true` → `(global non-optional catalog) ∪ (per-launcher mcp)`; `inheritGlobal=false` → `(per-launcher mcp)` only. Then `excludeMcp` subtracts.
5. **bubblewrap** masks project-level discovery paths in every ancestor of `$PWD` up to (exclusive) `$HOME`: `.claude/` → tmpfs, `.claude-plugin/` → tmpfs, `.mcp.json` → `--ro-bind /dev/null`, `CLAUDE.md` → `--ro-bind /dev/null`. The process sees the cwd as normal; only the launcher's claude (and its descendants) see masked entries.

## `mkClaudeLauncher` attribute reference

Every attr is listed in `claude-algo.nix` with its default value and comment, so the surface is discoverable at the call site. Summary:

### Additive (layered onto inherited base)
| Attr | Type | Effect |
|---|---|---|
| `skills` | attrset `{ <name> = <path>; }` | Symlinked into `~/.claude/skills/<name>/` inside the launcher state dir. |
| `agents` | attrset `{ <name> = <md-path>; }` | Symlinked into `~/.claude/agents/<name>.md`. |
| `commands` | attrset `{ <name> = <md-path>; }` | Symlinked into `~/.claude/commands/<name>.md`. Use `notesCmd "foo"` for live Notes paths. |
| `plugins` | `[ "<plugin@source>" … ]` | Flipped to `true` in `settings.json.enabledPlugins`. |
| `mcp` | `[ "<registry-name>" … ]` | Resolved from `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` at launch, written to `.mcp.json`. |

### Composition mode
| Attr | Default | Effect |
|---|---|---|
| `inheritGlobal` | `true` | When true, the additive lists *layer on top* of inherited globals; subtractive lists remove from the inherited set. When false, only the additive lists are wired (legacy "total replacement"; used by `claude-news` to keep the MCP set lean). |

### Subtractive (drop named entries from the inherited global set; no-op when `inheritGlobal = false`)
| Attr | Type | Effect |
|---|---|---|
| `excludeSkills` | `[ "<name>" … ]` | Bare names. Skipped during the upstream mirror loop. |
| `excludeAgents` | `[ "<name>" … ]` | Bare names — no `.md` extension. |
| `excludeCommands` | `[ "<name>" … ]` | Bare names — no `.md` extension. |
| `excludePlugins` | `[ "<plugin@source>" … ]` | `del(.enabledPlugins[$p])` — falls back to whatever global default is (rather than explicit `false`). |
| `excludeMcp` | `[ "<registry-name>" … ]` | Removed from the resolved MCP set before .mcp.json is written. |

### Permissions
| Attr | Default | Effect |
|---|---|---|
| `allowedTools` | `[]` | Appended (deduped) into `settings.permissions.allow`. |
| `deniedTools` | `[]` | Appended (deduped) into `settings.permissions.deny`. |

Pattern syntax matches Claude Code's permission grammar — e.g. `"Bash(curl:*)"`, `"Read(/etc/**)"`, `"WebFetch"`, `"mcp__mermaid__*"`.

### Hooks
| Attr | Default | Effect |
|---|---|---|
| `hooks` | `null` | When non-null, **REPLACES** the inherited global `settings.json.hooks` block wholesale (intentional isolation: e.g. don't run the global caveman Stop hook in claude-news). Same shape as `programs.claude-code.settings.hooks`. |

### Filesystem restriction
| Attr | Default | Effect |
|---|---|---|
| `restrictToDirs` | `null` | When non-null: (a) `settings.permissions.additionalDirectories = $dirs` (Claude's built-in Read/Write/Edit honor it); (b) if `filesystem` ended up in the resolved MCP set, its `args` are rewritten to `$dirs` so the upstream MCP server refuses paths outside (strict half); (c) sensitive-path Read denies (`~/.ssh`, `~/.gnupg`, sops, age, `/etc`, `/var`, `/root`) appended to `permissions.deny` (advisory half). |

**Caveat**: `permissions.deny` is advisory. Claude obeys deny patterns but a Bash invocation that the model frames cleverly could still touch arbitrary paths. The MCP-level filesystem narrowing is the strict one. If hard sandboxing is required, the bubblewrap call in `default.nix:exec bwrap …` would need to be reworked to bind only `restrictToDirs` + state dirs + minimal system paths — not currently done.

### Model / effort
| Attr | Default | Effect |
|---|---|---|
| `model` | `null` | When non-null, jq-pinned to `settings.json.model` at every launch. Caveat: in-session `/model` switches persist to `~/.claude.json` (shared), leaking to other launchers. |
| `effort` | `null` | `"low"`/`"medium"`/`"high"`/`"xhigh"`/`"auto"` (`"max"` is transient-only). jq-pinned to `settings.json.effortLevel`. |

## State dir

`$XDG_STATE_HOME/claude-launchers/<stateName>/` (defaults to `~/.local/state/claude-launchers/<stateName>/`). Refreshed on every launch — top-level symlinks re-pointed, `skills/`/`agents/`/`commands/` rebuilt (stale launcher-managed symlinks pruned; real files written there by Claude Code are preserved).

## Adding a new launcher

1. Drop a file `claude-launchers/<name>.nix` in this dir following the shape of `claude-algo.nix` (every supported attr listed explicitly — copy that file as a starting template).
2. If the launcher needs a flake input for a skill/agent/command source, add it to `flake.nix` and reference via `inputs.<name>`.
3. To reference an MCP by name, make sure it's registered in `modules/common/mcp-servers.nix` or `local.extraMcpServers` (claude.nix) so it appears in the runtime catalog at `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json`.
4. Run `scripts/nix_switch`.

The auto-discover loop in `default.nix` (`builtins.readDir ./.`) picks up the file on the next eval. No edit to `default.nix` needed.

## Currently shipped

- **`claude-algo`** — adds `inputs.algo-sensei` (karanb192/algo-sensei). `inheritGlobal = true`. Reference for the "extra resources on top of global" launcher pattern.
- **`claude-news`** — `inheritGlobal = false`, MCP set `[ "freshrss" "fetch" "basic-memory" ]`, three slash commands from `Notes/claude/lazy/personal/commands/`: `/digest [N]` (categorized summary of unread items), `/ask-news <question>` (search FreshRSS → fetch hits → synthesize with citations), `/starred [N]` (reading-list view). `restrictToDirs = [ "${config.home.homeDirectory}/killuanix/Notes" ]` pins the session to the Notes vault. The FreshRSS server itself is `optional = true` in `freshrss-mcp/default.nix`, so plain `claude` outside this launcher does not load it.
- **`claude-discover`** — `inheritGlobal = false`, MCP set `[ "kindly-web-search" "fetch" "basic-memory" ]`, `effort = "high"`. Slash command `/find <use-case>` invokes the `discover-resource` skill (lives at `Notes/claude/lazy/personal/skills/discover-resource/`). Skill walks: (Step 0) check local catalog at `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` + `Notes/claude/lazy/*/catalog.json`; (Step 2) query the official MCP registry, Glama, PulseMCP, anthropics/skills, anthropics/claude-plugins-official, wshobson/agents, davila7/claude-code-templates, ruvnet/ruflo, VoltAgent/awesome-claude-code-subagents in parallel via `mcp__fetch__fetch` / `gh api`; (Step 3) disambiguate similarly-named hits by fetching READMEs; (Step 4) print one concrete install snippet per recommendation (mostly `claude-kit lazy add …` or a nix stanza for the registry). `restrictToDirs` covers Notes + `~/.local/share/claude-kit` + `~/.cache/claude-kit` so the local-catalog read in Step 0 has no prompts. Scrape-only registries (MCP.so, Smithery, claudemarketplaces.com, buildwithclaude.com, SkillsMP, awesome-* markdown indexes) are deferred — add them by extending the skill's "Step 2 — per-type query plan" section.

## Integration

`default.nix` is imported by `../default.nix` (the AI module aggregator) as `./claude-launchers`. The dir resolves to `claude-launchers/default.nix` automatically. Ultimately pulled into `modules/cross-platform/default.nix` for all platforms.
