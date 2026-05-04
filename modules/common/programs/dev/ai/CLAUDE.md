# AI Module

Home Manager module for AI coding tools — Claude Code (and its surrounding ecosystem of CLIs, resource bundles, and MCP servers), OpenCode, and the MCP servers wired into them. Shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `opencode.nix`, `claude.nix`, `claude-resources.nix`, `claude-kit.nix`, `claude-launchers.nix`, `ruflo-cli.nix`, `claude-flow-cli.nix`, `ccr.nix`, `ccmanager.nix`, `code-index.nix`, and `jupyter-env-mcp.nix`. |
| `claude.nix` | Enables `programs.claude-code` and wires up skills and MCP servers. `skillRoots` is **only** local `./skills/` now (the always-on shortlist) — upstream bundles are lazy-loaded via the catalog (see "Lazy resource catalog" below). `extraSkills` cherry-picks individual upstream skills you want loaded everywhere (e.g. `er-diagram-and-data-modeling` from `vibekit`). MCP servers come from the registry at `modules/common/mcp-servers.nix`; catalog entries resolve to `natsukium/mcp-servers-nix` binaries, git-sourced entries are wrapped by `mkGitServer` (copies the optionally-patched source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` for `uv run`), `npxDirect` entries by `mkNpxDirectServer` (lazy `npx --yes`), and `uvxDirect` entries by `mkUvxDirectServer` (lazy `uvx`). `enabledPlugins` is empty by default — opt in per-project via `claude-kit lazy add plugin …`. Also wires the canonical Claude memory location: `~/.claude/CLAUDE.md` is a `mkOutOfStoreSymlink` to `Notes/claude/global.md`, and `~/.claude/projects/-home-killua-killuanix/memory` is a symlink to `Notes/claude/memory/`. |
| `claude-resources.nix` | Builds the upstream catalog from `ruvnet/ruflo` and `wshobson/agents` flake inputs. Same `mkFlatMarkdown` derivations produce flat `agents/`, `commands/`, and `skills/` dirs (one entry per resource, named `ruflo--<subpath>.md` or `wshobson--<plugin>--<name>.md`). **No longer installs into `~/.claude/`** — instead emits `Notes/claude/lazy/upstream/catalog.json` (a derivation listing every entry with its nix-store path, including the `anthropics/skills` bundle), symlinked into the Notes vault via a `home.activation.lazyUpstreamCatalogSymlink`. Read-only source symlinks under `~/.cache/claude-kit/sources/` are preserved so `claude-kit` can resolve store paths without globbing. |
| `claude-kit.nix` | Terminal utility (`claude-kit`) for browsing installed resources and managing the lazy catalog. Subcommands: `list`/`show`/`search`/`run`/`source` for browsing items in `~/.claude/`; **`lazy …` for the per-project opt-in catalog** (`ls`, `show`, `add`, `rm`, `project`, `new`, `refresh`, `doctor`); `plugin <install\|uninstall\|enable\|disable\|update\|list>` pass-through to `claude plugin …`; `marketplace <list\|add\|remove>` edits `~/.claude/settings.json` via `jq`; `mcp …` pass-through to `claude mcp …`; `ruflo …` pass-through to the ruflo CLI; plus `doctor` and `version`. Uses `fzf` + `bat` for search preview when on a TTY. |
| `claude-launchers.nix` | Sister wrappers around `claude` that boot Claude Code with curated extra skills layered on top of the global config — without putting those skills into `~/.claude/skills/` for plain `claude` invocations. Each launcher exports `CLAUDE_CONFIG_DIR=$XDG_STATE_HOME/claude-launchers/<name>/`; that dir mirrors every top-level entry of `~/.claude/` (auth, MCP, agents, commands, settings, projects, …) as symlinks and rebuilds `skills/` from the upstream set + curated extras. Currently ships `claude-algo` (adds `inputs.algo-sensei` only). See "## Per-launch skill bundles" below. |
| `ruflo-cli.nix` | Light `ruflo` CLI shim — a `writeShellApplication` that lazy-installs ruflo under `$XDG_CACHE_HOME/ruflo/` on first run via `npx --yes ruflo@<version>` using the existing `nodejs_20` package. No build-time npm closure; first invocation downloads, subsequent invocations are instant. Pinned `rufloVersion` string at the top of the file should be kept aligned with the `ruflo` flake-input rev. |
| `claude-flow-cli.nix` | Companion shim for `claude-flow` (= `npx --yes @claude-flow/cli@<version>`). Same lazy-install pattern as `ruflo-cli.nix` but for the runtime CLI invoked by `ruflo init`'s post-init guidance (`claude-flow daemon start`, `memory init`, `swarm init`, `init --start-all`) and by the `.mcp.json` server entry that `ruflo init` writes. Cache lives under `$XDG_CACHE_HOME/claude-flow/`. Pinned `claudeFlowVersion` should track `rufloVersion` in the sibling shim. |
| `ccr.nix` | Claude Code Router — Node daemon (lazy-`npx`) on `127.0.0.1:3456` that re-translates the Anthropic wire format to OpenAI-compatible providers. Configures NVIDIA NIM routing via a sops-rendered `~/.claude-code-router/config.json` (CCR can't read keys from a path), runs as a `systemd.user.services.ccr` always-on daemon on Linux (manual `ccr start` on macOS), and points `ANTHROPIC_BASE_URL` + a dummy `ANTHROPIC_API_KEY` at it via `home.sessionVariables` so every `claude`/`ruflo`/`claude-flow`/ccmanager-spawned session transparently routes through the configured model — no per-tool wrapping. |
| `ccmanager.nix` | Installs [kbwo/ccmanager](https://github.com/kbwo/ccmanager) (TUI for juggling multiple Claude Code sessions across git worktrees) using the same lazy-`npx` pattern as `ruflo-cli.nix`. Ships `ccmanager`, the `ccmgr` shortcut (= `ccmanager --multi-project`; `ccm` is taken by claude-monitor), and two worktree-hook binaries (`ccmanager-pre-creation-dedupe`, `ccmanager-post-creation-copy-staged`). Declaratively writes `~/.config/ccmanager/config.json` (read-only — TUI edits won't persist). Drives the `~/ccmanager-projects/` farm used by `--multi-project` from the `ccmanagerProjects` attrset at the top of the file — on Linux each entry becomes a `bindfs` FUSE mount managed by a systemd user service, on macOS it falls back to symlinks. See "## CCManager wiring" below. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |
| `code-index.nix` | Registers the custom `code-index` MCP server (built from `packages/code-index-mcp/` via uv2nix). Points `QDRANT_URL` at the local quadlet container (`http://127.0.0.1:6333`, see `modules/containers/qdrant.nix` — no API key on the local instance) and injects `NVIDIA_API_KEY_FILE` from sops. Lives outside `mcp-servers.nix` because it needs a secret path the catalog/git-source schema doesn't model. Indexed file types: `.java` (AST-chunked via tree-sitter), `.properties` (one chunk per key, handles `#`/`!` comments and backslash continuations — ATG `$class`/`$scope` keys fall out naturally), `.xml` (whole-file chunk keyed on the file stem). Extend `LANGUAGE_EXTENSIONS` + the dispatch in `_do_index` in `server.py` to add more. The `qdrant_cluster_endpoint` / `qdrant_api_key` entries in `modules/common/sops.nix` are now unreferenced (left in place for historical context; safe to remove). |
| `jupyter-env-mcp.nix` | Registers two cooperating Jupyter MCP servers: `jupyter-env` (local server built from `packages/jupyter-env-mcp/`) and `jupyter` (upstream `datalayer/jupyter-mcp-server` pinned by rev+hash). Bundles a `python3.withPackages` JupyterLab with `jupyter-collaboration` (RTC), `ipykernel`, `jupyterlab-lsp`, and `python-lsp-server`, plus a generated `jupyter_lab_config.py` + `overrides.json` that forces the Dark theme and 60s autosave via `JUPYTER_CONFIG_PATH`. Both servers live outside the registry because they share lifecycle wiring. |
| `patches/mcp-libre-calc-and-write.patch` | Local patch applied to the `libreoffice` MCP server (`patrup/mcp-libre`, unmaintained upstream). Fixes `create_document(doc_type="calc")` so it produces a real empty xlsx/ods via openpyxl instead of a 0-byte `touch()`, and adds a new `write_spreadsheet_data` tool that writes 2D cell data to `.xlsx`/`.ods` (ods round-trips through openpyxl + `soffice --convert-to`). Wired in via the `patches` field of the registry entry in `modules/common/mcp-servers.nix`. |
| `skills/` | Local skill subdirectories auto-collected by `claude.nix`. |

## Notable Configuration Details

- **OpenCode provider**: Uses a custom `gl4f` provider pointing to `https://g4f.space/api/nvidia` with the MiniMax M2.1 model.
- **Claude Code skills**: No hashes are maintained — skill sources come from flake inputs (`vibekit` for `extraSkills`) or local paths under `./skills/`. Every direct subdir of a `skillRoots` entry becomes a skill in `~/.claude/skills/` (always-on). Upstream bundles (`anthropics/skills`, `ruflo`, `wshobson`) are **not** in `skillRoots` anymore — they're in the lazy catalog and added per-project via `claude-kit lazy add skill <name>`. Local names override upstream on collision because `extraSkills` and later `foldl'` entries win.
- **MCP git-sourced servers**: `mkGitServer` keys the writable workdir on a 12-char slice of the store-path hash of the (possibly patched) source, so both rev bumps *and* patch edits invalidate the cached copy. Current runtime support is `uv-run` only.
- **MCP `uvxDirect` shape**: same pattern as `npxDirect` but for Python/PyPI packages. `uvx <package>` resolves and caches at first call under `$UV_CACHE_DIR=$XDG_CACHE_HOME/<cacheNamespace>/uv-cache`. Used by the `basic-memory` registry entry (markdown-backed knowledge graph MCP pointed at `Notes/claude/memory/`).
- **Claude memory canonical store**: `Notes/claude/global.md` and `Notes/claude/memory/` are the single source of truth. The Notes submodule is committed and pushed; `obsidian-git` auto-intervals are intentionally 0, so commits happen via the Obsidian command palette. The `memory-load` local skill (in `./skills/memory-load/`) describes how to retrieve memories on demand by trigger keyword instead of always-injecting them; the `basic-memory` MCP exposes `search_notes`, `read_note`, `edit_note` (prefer `append`/`replace_section` over `find_replace` against YAML frontmatter), `write_note`, `build_context`, `list_directory` against the same directory.
- **MCP registry patching**: Registry entries may set `patches = [./path/to.patch]`; `mkGitServer` runs `pkgs.applyPatches` before copying into the cache. Used by the `libreoffice` entry (see `patches/mcp-libre-calc-and-write.patch`).
- **Jupyter MCP pair**: `jupyter-env` owns Python-env provisioning (`uv venv` + `ipykernel install --user`) and the JupyterLab process lifecycle; it writes `~/.cache/jupyter-mcp/server.json` with `{url, token, port, pid}`. The `jupyter` wrapper reads that file to export `JUPYTER_URL`/`JUPYTER_TOKEN` on each spawn, falling back to placeholder values at boot so Claude Code's startup probe doesn't mark the server as failed before `start_jupyter` has run. RTC via `jupyter-collaboration` is required so notebook edits made by the upstream `jupyter` MCP propagate live to any open browser tab.
- **Jupyter env tools**: `create_env`, `list_envs`, `install_packages`, `delete_env`, `start_jupyter`, `stop_jupyter`, `jupyter_status`, `open_in_browser`. Envs land under `~/.local/share/jupyter-mcp/envs/<name>/`; default notebooks dir is `~/notebooks`.

## CCManager wiring

ccmanager is installed by `ccmanager.nix` using the same lazy-`npx` shim as `ruflo-cli.nix`. Everything ccmanager reads at startup is owned by Nix.

- **Config file**: `~/.config/ccmanager/config.json` is a **read-only** symlink into the Nix store (`xdg.configFile`). Editing in the TUI's "Global Configuration" screen silently fails on save — change the `cfg` attrset in `ccmanager.nix` and `home-manager switch`.
- **Key config choices**:
  - `autoApproval.enabled = false` — approvals stay in Claude.
  - `command.args = []` — no `--resume` by default; ccmanager owns session resume.
  - `worktree.autoDirectoryPattern = "../{project}-worktrees/{branch}"` — puts new worktrees in a sibling `*-worktrees/` dir per project.
  - `statusHooks` are intentionally omitted — no desktop notifications on idle/waiting/busy transitions.
- **Worktree hooks** are installed as first-class binaries so the JSON config can reference stable names, not store paths:
  - `ccmanager-pre-creation-dedupe` — aborts if `git worktree list` already has the branch or if the target path exists.
  - `ccmanager-post-creation-copy-staged` — `git diff --cached --name-only --diff-filter=ACMR -z | rsync --from0 --files-from=-` from source repo → new worktree. Carries over files the user has `git add`'d but not yet committed, so work-in-progress follows the branch. `.gitignore` is respected implicitly (ignored files can't be staged without `-f`); `--diff-filter=ACMR` skips deletions.
- **Multi-project root**: `home.sessionVariables.CCMANAGER_MULTI_PROJECT_ROOT = "$HOME/ccmanager-projects"`. The farm is built from the `ccmanagerProjects` attrset at the top of `ccmanager.nix` — add a project by appending `<name> = "<abspath>";`. On Linux each entry becomes a per-project **bindfs** FUSE mount driven by a systemd user service `ccmanager-bindfs-<name>.service`; HM activation only pre-creates the mountpoints and cleans up legacy symlinks (`-type l -delete`). On macOS the activation keeps the old symlink behavior. ccmanager's discovery scan (`Dirent.isDirectory()`) skips symbolic links, which is why a bind-mount is required for the Linux flow. Projects must be **real clones with a `.git/` directory** — bare-repo + worktree layouts fail `isMainGitRepository()` upstream and won't be listed.
- **bindfs service lifecycle**: each unit runs `bindfs -f --no-allow-other <path> ~/ccmanager-projects/<name>` as `Type=simple`; SIGTERM on `systemctl --user stop` unmounts cleanly. An `ExecStartPre` runs `fusermount3 -u` (prefixed `-`, failures ignored) to clear a stale mount if a previous instance crashed. `Restart = on-failure` with a 5 s backoff covers transient source-path issues. Stop with `systemctl --user stop ccmanager-bindfs-<name>`. `--no-allow-other` is required so we don't need `user_allow_other` in `/etc/fuse.conf`.
- **Stale-mount gotcha**: if the source directory is renamed/recreated while its bindfs unit is running, the mount keeps pointing at the old inode and starts returning stale (often empty) contents. `home-manager switch` re-emits the unit but won't restart it if the rendered ExecStart is unchanged, so the stale view persists. Fix: `systemctl --user restart ccmanager-bindfs-<name>`. Rule of thumb — restart the unit whenever a project's source path is touched outside of `home-manager switch`.
- **Git extension**: `programs.git.settings.extensions.worktreeConfig = true` is set in the sibling `dev/git.nix` so ccmanager's per-worktree `ccmanager.parentBranch` storage activates. Upstream docs specify graceful degradation when the extension isn't in effect (file diffs still render; ahead/behind info omitted), so repos where git ignores the global don't break.
- **Shortcut**: `ccmgr` = `ccmanager --multi-project` (name-collision with claude-monitor's `ccm`).
- **Version**: `ccmanagerVersion = "latest"` matches the `ruflo-cli.nix` convention. Pin explicitly if upstream ships a breaking change to hook env var names (`CCMANAGER_*`).

## Per-launch skill bundles

`claude-launchers.nix` provides Claude Code wrappers with extra skills scoped to that launcher only. Plain `claude` keeps the global skill set; `claude-algo` (and any future sibling) adds curated extras on top.

- **Why a wrapper, not just `programs.claude-code.skills`**: skills added to the global set are visible to *every* `claude` session. The launcher pattern keeps niche skills out of unrelated projects.
- **Why `CLAUDE_CONFIG_DIR` + symlinks (not just an alternate skills dir)**: setting `CLAUDE_CONFIG_DIR` makes Claude Code read its *entire* config tree — credentials, MCP servers, agents, commands, settings — from that path. An empty dir would force re-auth and drop every MCP server. The launcher mirrors every top-level entry of `~/.claude/` as a symlink so the alternate config is functionally identical to the global one, then overrides `skills/` with `<upstream skills> + <curated extras>`.
- **State dir**: `$XDG_STATE_HOME/claude-launchers/<stateName>/` (defaults to `~/.local/state/claude-launchers/<stateName>/`). Refreshed on every launch — top-level symlinks re-pointed and the `skills/` set rebuilt — but real files written there by Claude Code are preserved (only symlinks under `skills/` are pruned).
- **To add a launcher**: declare a new flake input (`flake = false`) for the skill source, then append another `mkClaudeLauncher { … }` to the `launchers` list. `extraSkills` is an attrset where the key becomes the skill dir name under `~/.claude/skills/<name>/` and the value is a path containing `SKILL.md`.
- **Currently shipped**: `claude-algo` → adds `karanb192/algo-sensei` via `inputs.algo-sensei`.

## Lazy resource catalog

Upstream resource bundles (ruflo + wshobson/agents + anthropics/skills) used to be flattened into `~/.claude/{agents,commands,skills}/` and listed in Claude Code's startup blob on every session — a major token-cost driver. Now they're in a **lazy catalog** under `Notes/claude/lazy/`, opted into per-project via `claude-kit lazy`.

### Layout

```
Notes/claude/lazy/
├── lazy.json              # optional metadata; sub-catalogs are auto-discovered
├── upstream/              # nix-managed; do not hand-edit
│   └── catalog.json       # symlink → /nix/store/.../catalog.json
├── personal/              # hand-curated; edit in Obsidian
│   ├── catalog.json       # regenerate via `claude-kit lazy refresh personal`
│   ├── skills/<name>/SKILL.md
│   ├── agents/<name>.md
│   └── commands/<name>.md
└── <user-catalog>/        # `claude-kit lazy new <name>` scaffolds this
```

The tree is exactly **one level deep**. Any subdir with `catalog.json` is auto-discovered as a sub-catalog.

### Source bundles in the upstream catalog

| Source | Pinned in `flake.nix` | Naming in catalog |
|---|---|---|
| `inputs.ruflo` | `01070ede81fa6fbae93d01c347bec1af5d6c17f0` | `ruflo--<subpath>` |
| `inputs.wshobson-agents` | `27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb` | `wshobson--<plugin>--<name>` |
| `inputs.anthropics-skills` | flake input | upstream name (no prefix) |

**To bump** any bundle:

1. `nix flake lock --update-input <name>`
2. If the ruflo npm CLI version changed, update `rufloVersion` in `ruflo-cli.nix`.
3. Update the matching `rev:` line in `claude-kit.nix cmd_version`.

The upstream catalog auto-regenerates on the next `nix_switch` — no further action.

### Per-project use

```
claude-kit lazy ls                          # browse all catalogs (with item counts)
claude-kit lazy ls upstream                 # contents of one catalog
claude-kit lazy ls --type skills            # filter across catalogs
claude-kit lazy show <type> <name>          # description + rendered file
claude-kit lazy add  <type> <name>          # symlink into cwd ./.claude/<type>/
claude-kit lazy add  <catalog>/<type>/<name>   # disambiguate
claude-kit lazy rm   <type> <name>          # remove from project scope
claude-kit lazy project [--global]          # list project-scope (--global also lists catalog)
claude-kit lazy new <name>                  # scaffold new sub-catalog under Notes/claude/lazy/
claude-kit lazy refresh <name>              # regenerate <name>/catalog.json from contents
claude-kit lazy doctor                      # validate manifests
```

Project-scope state lives at the paths Claude Code already reads per-project:

| Resource | Project location | Mechanism |
|---|---|---|
| skill   | `./.claude/skills/<name>/`    | symlink → catalog path |
| agent   | `./.claude/agents/<name>.md`  | symlink → catalog path |
| command | `./.claude/commands/<name>.md`| symlink → catalog path |
| plugin  | `./.claude/settings.local.json` `enabledPlugins.<name>=true` | jq edit |

### Plugin marketplace registration

`claude.nix` still registers `ruflo` as a marketplace via `programs.claude-code.settings.extraKnownMarketplaces.ruflo` (source `github:ruvnet/ruflo`) so per-project plugin enables (`claude-kit lazy add plugin ruflo-core@ruflo`) can resolve. The `enabledPlugins` attrset is **empty by default** — plugins are not auto-loaded globally anymore. To pin a specific marketplace ref, add `ref = "<rev>"` to `extraKnownMarketplaces.ruflo.source`.

### Always-on shortlist

What stays globally loaded (in `~/.claude/skills/`):

- The 7 local skills under `./skills/`: `code-exploration`, `code-search`, `excalidraw-sketches`, `memory-load`, `mermaid-diagrams`, `obsidian-clipper`, `obsidian-vault`.
- `extraSkills` in `claude.nix` (currently `er-diagram-and-data-modeling` from vibekit).

To add a frequently-used upstream skill to the always-on set, add it to `extraSkills` rather than enabling it per-project everywhere.

## Integration

`default.nix` is imported by the parent `modules/common/programs/dev/default.nix`, which is pulled into `modules/common/programs.nix` and ultimately `modules/cross-platform/default.nix` for all platforms.
