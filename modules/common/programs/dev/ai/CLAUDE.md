# AI Module

Home Manager module for AI coding tools — Claude Code (and its surrounding ecosystem of CLIs, resource bundles, and MCP servers), OpenCode, and the MCP servers wired into them. Shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `opencode.nix`, `claude.nix`, `claude-resources/`, `claude-kit/`, `claude-launchers.nix`, `ruflo-cli.nix`, `claude-flow-cli.nix`, `ccr.nix`, `ccmanager.nix`, `code-index.nix`, `gitnexus-cli.nix`, `jupyter-env-mcp.nix`, and `den/`. |
| `claude.nix` | Enables `programs.claude-code` and wires up skills and MCP servers. `skillRoots` is **only** local `./skills/` now (the always-on shortlist) — upstream bundles are lazy-loaded via the catalog (see "Lazy resource catalog" below). `extraSkills` cherry-picks individual upstream skills you want loaded everywhere (e.g. `er-diagram-and-data-modeling` from `vibekit`). MCP servers come from the registry at `modules/common/mcp-servers.nix`; catalog entries resolve to `natsukium/mcp-servers-nix` binaries, git-sourced entries are wrapped by `mkGitServer` (whose body now lives at `./claude/scripts/mcp-git-server.sh` — copies the optionally-patched source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` for `uv run`), `npxDirect` entries by `mkNpxDirectServer` (lazy `npx --yes`), and `uvxDirect` entries by `mkUvxDirectServer` (lazy `uvx`). `enabledPlugins` is empty by default — opt in per-project via `claude-kit lazy add plugin …`. Also wires the canonical Claude memory location: `~/.claude/CLAUDE.md` is a `mkOutOfStoreSymlink` to `Notes/claude/global.md`, and `~/.claude/projects/-home-killua-killuanix/memory` is a symlink to `Notes/claude/memory/`. |
| `claude/scripts/mcp-git-server.sh` | Wrapper body executed by Claude Code for git-sourced MCP servers. Reads `MCP_NAME` / `MCP_SRCKEY` / `MCP_SRC` / `MCP_RUNTIME` / `MCP_ENTRYPOINT` env vars (set by `mkGitServer` in `claude.nix`), copies the read-only nix-store source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` on first run, and exec's the runtime. Currently only `uv-run` is supported; extending to `pipx-run`/`npm-run` means adding a case here, not in nix. |
| `claude-resources/` | Builds the upstream catalog from `ruvnet/ruflo` + `wshobson/agents` + `anthropics/skills` flake inputs into the lazy catalog at `Notes/claude/lazy/upstream/catalog.json`. Was a single 220-line `.nix` with four embedded `runCommand` bash bodies; now a directory with `default.nix` + `build/{flat-markdown,flat-skills,upstream-catalog,upstream-bundles}.sh`. Each `runCommand` reads its bash body via `builtins.readFile` and passes nix-injected store paths (`$RUFLO`, `$WSHOBSON`, `$ANTHROPICS_SKILLS`, `$SKILLS_DIR`, `$AGENTS_DIR`, `$COMMANDS_DIR`) through env vars on the `runCommand` attrset. See `claude-resources/CLAUDE.md`. **No longer installs into `~/.claude/`** — read-only symlinks under `~/.cache/claude-kit/sources/` are preserved so `claude-kit` can resolve store paths without globbing, and the catalog + bundles are linked into `Notes/claude/lazy/upstream/` via `home.activation.lazyUpstreamCatalogSymlink`. |
| `claude-kit/` | Terminal utility (`claude-kit`) for browsing installed resources and managing the lazy catalog. Was a single 1282-line `.nix`; now a directory with `default.nix` (small `writeShellApplication` wrapper that bundles `scripts/` via `runCommand` and sets `CLAUDE_KIT_LIB_DIR`) + `scripts/claude-kit.sh` (entrypoint dispatcher) + `scripts/lib/{common,lazy,session}.sh` + `scripts/cmd/<name>.sh` (one per public subcommand) + `scripts/cmd/lazy/<name>.sh` (one per `lazy` verb, with `bundle.sh` internally dispatching the bundle subverbs). See `claude-kit/CLAUDE.md`. Subcommand surface: `list`/`show`/`search`/`run`/`source`/`clean`/`resume`/`doctor`/`version`; `lazy …` (`ls`/`show`/`add`/`rm`/`project`/`new`/`refresh`/`doctor` plus `bundle ls\|show\|add\|rm\|status`); `plugin`/`marketplace`/`mcp`/`ruflo` passthroughs. Uses `fzf` + `bat` for search preview when on a TTY. |
| `claude-launchers.nix` | Sister wrappers around `claude` that boot Claude Code with curated extra skills layered on top of the global config — without putting those skills into `~/.claude/skills/` for plain `claude` invocations. Each launcher exports `CLAUDE_CONFIG_DIR=$XDG_STATE_HOME/claude-launchers/<name>/`; that dir mirrors every top-level entry of `~/.claude/` (auth, MCP, agents, commands, settings, projects, …) as symlinks and rebuilds `skills/` from the upstream set + curated extras. Currently ships `claude-algo` (adds `inputs.algo-sensei` only). See "## Per-launch skill bundles" below. |
| `ruflo-cli.nix` | Light `ruflo` CLI shim — a `writeShellApplication` that lazy-installs ruflo under `$XDG_CACHE_HOME/ruflo/` on first run via `npx --yes ruflo@<version>` using the existing `nodejs_20` package. No build-time npm closure; first invocation downloads, subsequent invocations are instant. Pinned `rufloVersion` string at the top of the file should be kept aligned with the `ruflo` flake-input rev. |
| `claude-flow-cli.nix` | Companion shim for `claude-flow` (= `npx --yes @claude-flow/cli@<version>`). Same lazy-install pattern as `ruflo-cli.nix` but for the runtime CLI invoked by `ruflo init`'s post-init guidance (`claude-flow daemon start`, `memory init`, `swarm init`, `init --start-all`) and by the `.mcp.json` server entry that `ruflo init` writes. Cache lives under `$XDG_CACHE_HOME/claude-flow/`. Pinned `claudeFlowVersion` should track `rufloVersion` in the sibling shim. |
| `ccr.nix` | Claude Code Router — Node daemon (lazy-`npx`) on `127.0.0.1:3456` that re-translates the Anthropic wire format to OpenAI-compatible providers. Configures NVIDIA NIM routing via a sops-rendered `~/.claude-code-router/config.json` (CCR can't read keys from a path) and runs as a `systemd.user.services.ccr` always-on daemon on Linux (manual `ccr start` on macOS). Routing is **opt-in per invocation**: use `ccr code` to launch Claude Code through CCR. Plain `claude`/`ruflo`/`claude-flow`/ccmanager hit the real Anthropic API — no global `ANTHROPIC_BASE_URL` is set. |
| `ccmanager.nix` | Installs [kbwo/ccmanager](https://github.com/kbwo/ccmanager) (TUI for juggling multiple Claude Code sessions across git worktrees) using the same lazy-`npx` pattern as `ruflo-cli.nix`. Ships `ccmanager`, the `ccmgr` shortcut (= `ccmanager --multi-project`; `ccm` is taken by claude-monitor), and two worktree-hook binaries (`ccmanager-pre-creation-dedupe`, `ccmanager-post-creation-copy-staged`). Declaratively writes `~/.config/ccmanager/config.json` (read-only — TUI edits won't persist). Drives the `~/ccmanager-projects/` farm used by `--multi-project` from the `ccmanagerProjects` attrset at the top of the file — on Linux each entry becomes a `bindfs` FUSE mount managed by a systemd user service, on macOS it falls back to symlinks. See "## CCManager wiring" below. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |
| `code-index.nix` | Registers the custom `code-index` MCP server (built from `packages/code-index-mcp/` via uv2nix). Points `QDRANT_URL` at the local quadlet container (`http://127.0.0.1:6333`, see `modules/containers/qdrant.nix` — no API key on the local instance) and injects `NVIDIA_API_KEY_FILE` from sops. Lives outside `mcp-servers.nix` because it needs a secret path the catalog/git-source schema doesn't model. Indexed file types: `.java` (AST-chunked via tree-sitter), `.properties` (one chunk per key, handles `#`/`!` comments and backslash continuations — ATG `$class`/`$scope` keys fall out naturally), `.xml` (whole-file chunk keyed on the file stem). Extend `LANGUAGE_EXTENSIONS` + the dispatch in `_do_index` in `server.py` to add more. Companion `gitnexus` MCP (npm `gitnexus@latest`, stdio `gitnexus mcp`) is registered in `modules/common/mcp-servers.nix` via the npxDirect lane — it builds a per-repo Tree-sitter knowledge graph at `<repo>/.gitnexus/` (after `gitnexus analyze`) and answers relational queries (impact, call graphs, process tracing) that complement code-index's vector search rather than duplicating it. The `qdrant_cluster_endpoint` / `qdrant_api_key` entries in `modules/common/sops.nix` are now unreferenced (left in place for historical context; safe to remove). |
| `gitnexus-cli.nix` | Light `gitnexus` CLI shim — `writeShellApplication` lazy-installing `gitnexus@<pinned>` under `$XDG_CACHE_HOME/gitnexus/{npm-cache,npm-prefix}` via `npx --yes`, mirroring `ruflo-cli.nix`. Cache namespace is shared with the `gitnexus` MCP entry in `modules/common/mcp-servers.nix` (`cacheNamespace = "gitnexus"`, same trick as the `claude-flow ↔ ruflo` pair documented there) so Claude Code's MCP connect probe doesn't pay a second cache resolution on cold start. CLI surface includes `analyze` (build per-repo index → `<repo>/.gitnexus/`, gitignored globally via `programs/dev/git.nix`), `list`, `status`, `clean`, `mcp`, plus `serve` (HTTP UI on :4747, run manually if desired) and `wiki` (LLM-generated docs, needs `OPENAI_API_KEY`, not wired). Upstream is **PolyForm Noncommercial** — fine for personal/dev use. `gitnexus analyze` must run once per repo before the MCP returns useful results; `~/.gitnexus/registry.json` is the global pointer file. |
| `jupyter-env-mcp.nix` | Registers two cooperating Jupyter MCP servers: `jupyter-env` (local server built from `packages/jupyter-env-mcp/`) and `jupyter` (upstream `datalayer/jupyter-mcp-server` pinned by rev+hash). Bundles a `python3.withPackages` JupyterLab with `jupyter-collaboration` (RTC), `ipykernel`, `jupyterlab-lsp`, and `python-lsp-server`, plus a generated `jupyter_lab_config.py` + `overrides.json` that forces the Dark theme and 60s autosave via `JUPYTER_CONFIG_PATH`. Both servers live outside the registry because they share lifecycle wiring. |
| `patches/mcp-libre-calc-and-write.patch` | Local patch applied to the `libreoffice` MCP server (`patrup/mcp-libre`, unmaintained upstream). Fixes `create_document(doc_type="calc")` so it produces a real empty xlsx/ods via openpyxl instead of a 0-byte `touch()`, and adds a new `write_spreadsheet_data` tool that writes 2D cell data to `.xlsx`/`.ods` (ods round-trips through openpyxl + `soffice --convert-to`). Wired in via the `patches` field of the registry entry in `modules/common/mcp-servers.nix`. |
| `skills/` | Local skill subdirectories auto-collected by `claude.nix`. |
| `den/` | `den` — project-scoped symlink + patch manager. Was a single 2944-line `.nix`; now a directory with `default.nix` (HM module + `runCommand` bundling) + `scripts/den.sh` (entrypoint sourcing all libs/cmds eagerly + dispatching to `den_cmd_<name>`) + `scripts/lib/{common,meta,bindings,store,hooks,generations}.sh` + `scripts/cmd/<name>.sh` (one per subcommand, ~34 files; `re-add.sh`, `last-applied.sh` use hyphenated filenames; functions use underscores via `den_cmd_<name>`) + `helper/main.py` (argparse dispatcher) + `helper/lib/{toml_io,ignore,manifest}.py` + `helper/cmd/{walk,manifest_hash,status,jsonl,toml}.py`. Wrapper sets `DEN_LIB_DIR` and `DEN_HELPER_BIN` env vars; the python sidecar is wired via `sys.path.insert(0, "${denHelperLib}")` in a tiny `writePython3Bin` entry stub. Bash CLI binds named projects under `Notes/projects/<NAME>/` to working directories via symlinks. Two-tier metadata: `Notes/projects/<NAME>/.den-project.toml` (project marker, pushed) + `<bound-cwd>/.den-meta.json` (host-side, globally gitignored via `programs/dev/git.nix`). Hybrid manifest (auto-walk `files/`; `manifest.toml` only for entries needing metadata). Linux-only. See `## den` below and `den/CLAUDE.md`. |

## Notable Configuration Details

- **OpenCode provider**: Uses a custom `gl4f` provider pointing to `https://g4f.space/api/nvidia` with the MiniMax M2.1 model.
- **claude-kit cache prune**: `~/.cache/claude-kit/{sessions,sources}` is pruned daily (>7 days old) by the Cronicle event defined in `modules/containers/cronicle/events/claude-kit-prune.nix`. Set `enabled = false` in that file to grey it out in Cronicle (event stays visible, Active checkbox off). Transient pause without a rebuild: toggle the UI's "Active" checkbox at http://localhost:3012 — sticky as long as nix's `enabled` stays true. The `/tmp/claude-kit-*` working dirs are still cleaned at script exit by traps inside `claude-kit/scripts/`.
- **Embedded-script extraction pattern**: `claude-resources/`, `claude-kit/`, `den/`, and `claude/scripts/mcp-git-server.sh` follow a single convention — bash bodies live as plain `.sh` files (with `#!/usr/bin/env bash` shebangs, real shellcheck), python bodies as plain `.py` files, both bundled into the store via `pkgs.runCommand "name" {} '' cp -r ${./scripts}/* $out/ ''`. The `writeShellApplication` (or `runCommand`) wrapper does **only one job**: set env vars for any nix-injected values (store paths, version pins, config strings) and `exec bash $LIB_DIR/entry.sh "$@"`. **No `${nix}` interpolation inside `.sh`/`.py`** — every nix-side value enters the script as `$ENV_VAR`. This keeps a shell/python LSP fully functional inside the source files. New per-script directives (`# shellcheck disable=…`, `# noqa: …`) live inline rather than as `excludeShellChecks` / `flakeIgnore` on the wrapper. Threshold for extraction is ~20 lines of embedded body; smaller wrappers (e.g. `mkNpxDirectServer`/`mkUvxDirectServer` in `claude.nix`) stay inline.
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

### Bundles — activate a stack in one shot

A **bundle** is a JSON manifest at `<catalog>/bundles/<name>.json` listing plugins/MCP/skills/agents/commands to enable together. The upstream catalog ships a `ruflo` bundle (8 ruflo plugins, generated from `claude-resources.nix:upstreamBundles`). Add new bundles by hand-writing `<personal-catalog>/bundles/<name>.json`.

```
claude-kit lazy bundle ls                   # list bundles (* marks applied to cwd)
claude-kit lazy bundle show <name>          # print bundle contents (jq+bat)
claude-kit lazy bundle add <name>           # apply: merge plugins, mcp, symlinks
claude-kit lazy bundle rm <name>            # reverse using ./.claude/.lazy-bundles.json state
claude-kit lazy bundle status               # what's applied to cwd
```

Apply state is tracked in `./.claude/.lazy-bundles.json` so `rm` reverses precisely what `add` wrote (regardless of whether the bundle JSON has changed since). When the state file becomes empty, it's auto-deleted.

**Ruflo workflow** — bundle activation is composed with `ruflo init`:

```
cd ~/projects/foo
ruflo init                                  # writes .mcp.json + .claude-flow/ + .swarm/
claude-kit lazy bundle add ruflo            # writes 8 plugins into .claude/settings.local.json
claude                                      # session has full ruflo stack
```

Outside `~/projects/foo` (or any directory without `.mcp.json` + `settings.local.json`), Claude Code stays lean — no ruflo, no claude-flow, no plugin tools in the startup blob. To deactivate the bundle in `~/projects/foo`, run `claude-kit lazy bundle rm ruflo` (the `.mcp.json` and `.claude-flow/` from `ruflo init` are not touched — they're upstream's responsibility to clean up if you want).

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

## den

`den.nix` ships the `den` CLI (Bash + a `den-helper` Python sidecar) for project-scoped state management. Each named project lives at `Notes/projects/<NAME>/` and is bound to a single working directory via symlinks; the binding is recorded host-side in `<cwd>/.den-meta.json` and is invisible to git (globally ignored via `programs/dev/git.nix`).

### Two-tier metadata

| File | Where | Pushed? | Role |
|---|---|---|---|
| `.den-project.toml` | `Notes/projects/<NAME>/` | yes | Project marker: `name`, `visibility`, `preset`, `schema_version`. |
| `.den-meta.json` | bound cwd | **no** (globally gitignored) | Binding marker + applied-symlinks ledger + host-only list + `lastop`. |
| Nix host overlay | `~/.local/share/den/overlay/<NAME>/` | no (HM-managed) | `scope = "host"` files/hooks declared in `programs.den`. |

### Path resolution (only `new`/`init`)

- default: prefer `git rev-parse --show-toplevel` if cwd is in a work-tree, else cwd
- `den new NAME .` — force cwd, warn if inside a git repo
- `den new NAME --path P` — explicit path

All other commands (`status`/`pull`/`ls`/etc.) walk upward from cwd looking for `.den-meta.json`.

### Source layout

```
Notes/projects/<NAME>/
├── .den-project.toml
├── files/                 # auto-walked; symlinked into bound cwd
├── manifest.toml          # OPTIONAL — only for entries needing metadata
├── .denignore             # gitignore-syntax; never symlinked
├── .activity/<host>.jsonl # append-only activity log (per-host = no merges)
├── patches/<series>/      # 0001-*.patch with Den-Series:/Den-Anchor: trailers
│                          # + meta.toml + optional description.md +
│                          # index.diff/worktree.diff/untracked.tar (three-tree split)
└── hooks/<event>          # shared hooks (pre-pull, post-pull, etc.)
```

### Hook lifecycle (full set)

`pre-pull`/`post-pull`, `pre-clean`/`post-clean`, `pre-add`/`post-add`, `pre-sync`/`post-sync`, `pre-stash`/`post-stash`, `pre-apply`/`post-apply`. Two scopes:

- `shared` — written into `Notes/projects/<NAME>/hooks/` by HM activation. Refuses to clobber files that don't carry the `# den-managed (do not edit)` first-line marker, so user edits in Notes survive a rebuild.
- `host` — written via `home.file` to `~/.local/share/den/overlay/<NAME>/hooks/`. Must be `den hooks trust <event>`'d on each host before `den` will run them (mirrors direnv's content-hash allow). SHA stored in `.den-meta.json.trusted_hooks`.

### Nix module surface

```nix
programs.den.projects.myproj = {
  hooks.pre-pull = {
    scope = "host";              # or "shared"
    text = "echo killua-only";
    executable = true;
  };
  files.".env.host" = {
    scope = "host";
    text = "APP_HOST=killua";
  };
};
```

Top-level options: `programs.den.{enable,notesPath,snapshotContent,zoxide,starshipBlock}`. Linux-only — the module body is gated on `pkgs.stdenv.isLinux`.

### Subsystems

- **Hybrid manifest**: `files/` is auto-walked; `manifest.toml` is the override list only.
- **Status**: 5 buckets — `missing-link`, `wrong-target`, `replaced-with-real-file`, `unmanaged-real-file`, `untracked` (real files in cwd, not host-only, not ignored). Mirror of `git status` UX with `den add` / `den ignore` hints.
- **Transactional pull**: builds new symlinks under `<cwd>/.den-staging/`, journal-driven rollback on failure, per-cwd `flock` on `.den-meta.json.lock`.
- **Patches**: `den stash` produces a numbered series with `Den-Series:`/`Den-Anchor:` trailers (gerrit-style) plus a three-tree split (committed format-patch + `index.diff` + `worktree.diff` + `untracked.tar`). `den apply` runs `git am --3way`; `--continue`/`--abort`/`--onto`/`--dry-run`/`--reverse` mirror `git rebase` UX.
- **Per-host CAS**: `~/.local/share/den/cas/objects/<aa>/<bb…>` (sha256-loose, ungzipped) for patch content + 3-way merge anchor blobs. Two-clock GC (`gc.cas.unrefExpire = 14d` / `gc.cas.reflogExpire = 90d`). Regenerable via `den gc --rebuild`.
- **Generations**: per-cwd snapshots at `<cwd>/.den-generations/gen-NNN.json`. Pointer-only by default (pin `notes_commit_sha`); set `programs.den.snapshotContent = true` for tarball-content fallback if Notes ever force-pushes. `den rollback` is **symlinks-only** — to reverse a patch's git effect, run `den apply <S> --reverse` separately.
- **Reflog**: per-cwd JSONL at `.den-meta.json.reflog`. Recovers bindings after `den clean` (read prior `project` field, run `den init <prev>`).
- **Activity log**: per-host JSONL under `Notes/projects/<NAME>/.activity/<host>.jsonl`. `den last-applied` reads all hosts; `den log` reads this host.
- **Doctor**: invariants I1–I7 with `den explain I<n>`. Lax by default (missing `Den-Anchor:` is info, not drift); `den doctor --strict` flips it.
- **Layered config (`den config`)**: 4-tier mirror of `git config` (Nix defaults → `~/.config/den/config.toml` → `.den-project.toml [config]` → `.den-meta.json.config`).
- **Convenience**: `den re-add` (chezmoi-style ingest editor-atomic-save replacements), `den restore` (undo `den add`, mirrors `git restore`), `den which`, `den cd`, `den exec`, `den activate` (env exports: `DEN_PROJECT`/`DEN_PROJECT_ROOT`/`DEN_BOUND_AT`/`DEN_HOST`/`CLAUDE_PROJECT_DIR`).
- **Shell integration**: `den completion {bash,zsh,fish}` auto-wired into HM `fpath`; Starship `[custom.den]` block auto-configured (toggle via `programs.den.starshipBlock = false`).
- **Subcommand discovery**: any `den-foo` binary on PATH is reachable as `den foo` (git-style).
- **zoxide hand-off**: `den pull` opportunistically runs `zoxide add "$bound_cwd"` when zoxide is on PATH (toggle via `programs.den.zoxide = false`).

### Presets

- `bare` — empty skeleton.
- `minimal` — `files/CLAUDE.md` placeholder + minimal `.denignore`.
- `claude-full` (default) — `CLAUDE.md` + `.claude/{settings.json,commands/,agents/,skills/,output-styles/}` + `.mcp.json` + a `.denignore` that filters out `CLAUDE.local.md`, `.claude/settings.local.json`, `.env*`, `*.local.md`.

### Linking strategy

`kind = "symlink"` is the default (absolute symlink from cwd into `Notes/projects/<N>/files/<rel>`). Per-file overrides live in `manifest.toml`:

- **`kind = "hardlink"`** — same-filesystem hardlink. Both paths share an inode and look like a real file. Required for files whose readers don't follow symlinks pointing outside their own tree — most notably `flake.nix` (nix flakes copy the source to `/nix/store/<hash>-source/` before evaluating, then mis-resolve absolute symlink targets relative to that copy, producing errors like `path '/nix/store/.../source/home/.../files/flake.nix' does not exist`). Add with `den add --hardlink <path>`. The flag persists as `[[entry]] kind = "hardlink"` in `manifest.toml`, so subsequent `den pull` on other hosts re-creates the hardlink for that file. Editor atomic-saves (write-tmp + rename) break the inode link; `den status` flags this as `replaced-with-real-file` and `den re-add <path>` rebuilds it. Cross-fs hardlink errors out at add time.
- **`kind = "bind"`** — FUSE bindfs, modeled on the existing `ccmanager-bindfs-*` units. Parsed in `manifest.toml` but defers to v2 with a friendly error.
- Reflinks/runtime-OverlayFS rejected on technical grounds (cross-fs, cleanup, snapshot semantics).

The `.den-meta.json.symlinks` ledger entries carry a `kind` field so `clean` / `restore` / `doctor` can branch correctly. Older entries without `kind` default to `"symlink"`.

### Integration touch-points

- `default.nix` — adds `./den.nix` to the imports list.
- `programs/dev/git.nix` — extends `programs.git.ignores` with `.den-meta.json`/`.den-meta.json.lock`/`.den-meta.json.reflog`/`.den-staging/`/`.den-generations/` so `den` host state never appears in any project's `git status`.
- `Notes/.gitignore` — belt-and-suspenders ignore patterns under `projects/*/`.

## Integration

`default.nix` is imported by the parent `modules/common/programs/dev/default.nix`, which is pulled into `modules/common/programs.nix` and ultimately `modules/cross-platform/default.nix` for all platforms.
