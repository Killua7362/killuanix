# Dev Module

Home Manager module for development tools shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `git.nix`, `lazygit.nix`, `opencode.nix`, `claude.nix`, `claude-resources.nix`, `claude-kit.nix`, `ruflo-cli.nix`, `ccmanager.nix`, `code-index.nix`, and `jupyter-env-mcp.nix`. |
| `git.nix` | Git configuration. Sets user identity from `commonModules.user.userConfig`. Enables `extensions.worktreeConfig` globally so ccmanager can persist per-worktree config (e.g. `ccmanager.parentBranch`). Includes a conditional include for Azure DevOps repos that swaps in Boeing credentials (decrypted via sops) and routes traffic through a SOCKS5 proxy at `127.0.0.1:1080`. |
| `lazygit.nix` | Lazygit configuration. Defines a full custom keybinding map covering universal navigation, file staging, branch operations, commits, stash, submodules, and merge conflict resolution. |
| `claude.nix` | Enables `programs.claude-code` and wires up both skills and MCP servers. Auto-collects every subdirectory under each entry in `skillRoots` (upstream `anthropics/skills` + local `./skills`) into `programs.claude-code.skills`, plus cherry-picked `extraSkills` (e.g. `er-diagram-and-data-modeling` from `vibekit`). MCP servers come from the registry at `modules/common/mcp-servers.nix`; catalog entries resolve to `natsukium/mcp-servers-nix` binaries, while git-sourced entries are wrapped by `mkGitServer`, which copies the (optionally patched) source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` so runtimes like `uv run` have a writable workdir. |
| `claude-resources.nix` | Flattens two external bundles into `~/.claude/{agents,commands,skills}/`: `ruvnet/ruflo` (108 agents + 168 commands + 41 skills) and `wshobson/agents` (184 agents + 98 commands + 150 skills across 78 plugins). Builds three derivations via `pkgs.runCommand` that copy the markdown with unique prefixes — `ruflo--<subpath>.md` and `wshobson--<plugin>--<name>.md` — since Claude Code's standalone `~/.claude/` tree is flat (no namespacing from nested dirs). Wires agents/commands via `home.file` with `recursive = true` (so user-created files are preserved), and merges skills into the existing `programs.claude-code.skills` attrset. Also exposes read-only source symlinks under `~/.cache/claude-kit/sources/`. |
| `claude-kit.nix` | Terminal utility (`claude-kit`) wrapping the resources installed above. Subcommands: `list`/`show`/`search`/`run`/`source` for browsing installed items; `plugin <install\|uninstall\|enable\|disable\|update\|list>` pass-through to `claude plugin …`; `marketplace <list\|add\|remove>` edits `~/.claude/settings.json` via `jq`; `mcp …` pass-through to `claude mcp …`; `ruflo …` pass-through to the ruflo CLI; plus `doctor` and `version`. Uses `fzf` + `bat` for search preview when on a TTY. |
| `ruflo-cli.nix` | Light `ruflo` CLI shim — a `writeShellApplication` that lazy-installs ruflo under `$XDG_CACHE_HOME/ruflo/` on first run via `npx --yes ruflo@<version>` using the existing `nodejs_20` package. No build-time npm closure; first invocation downloads, subsequent invocations are instant. Pinned `rufloVersion` string at the top of the file should be kept aligned with the `ruflo` flake-input rev. |
| `ccmanager.nix` | Installs [kbwo/ccmanager](https://github.com/kbwo/ccmanager) (TUI for juggling multiple Claude Code sessions across git worktrees) using the same lazy-`npx` pattern as `ruflo-cli.nix`. Ships `ccmanager`, the `ccmgr` shortcut (= `ccmanager --multi-project`; `ccm` is taken by claude-monitor), and two worktree-hook binaries (`ccmanager-pre-creation-dedupe`, `ccmanager-post-creation-copy-staged`). Declaratively writes `~/.config/ccmanager/config.json` (read-only — TUI edits won't persist). Drives the `~/ccmanager-projects/` farm used by `--multi-project` from the `ccmanagerProjects` attrset at the top of the file — on Linux each entry becomes a `bindfs` FUSE mount managed by a systemd user service, on macOS it falls back to symlinks. See "## CCManager wiring" below. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |
| `code-index.nix` | Registers the custom `code-index` MCP server (built from `packages/code-index-mcp/` via uv2nix). Points `QDRANT_URL` at the local quadlet container (`http://127.0.0.1:6333`, see `modules/containers/qdrant.nix` — no API key on the local instance) and injects `NVIDIA_API_KEY_FILE` from sops. Lives outside `mcp-servers.nix` because it needs a secret path the catalog/git-source schema doesn't model. Indexed file types: `.java` (AST-chunked via tree-sitter), `.properties` (one chunk per key, handles `#`/`!` comments and backslash continuations — ATG `$class`/`$scope` keys fall out naturally), `.xml` (whole-file chunk keyed on the file stem). Extend `LANGUAGE_EXTENSIONS` + the dispatch in `_do_index` in `server.py` to add more. The `qdrant_cluster_endpoint` / `qdrant_api_key` entries in `modules/common/sops.nix` are now unreferenced (left in place for historical context; safe to remove). |
| `jupyter-env-mcp.nix` | Registers two cooperating Jupyter MCP servers: `jupyter-env` (local server built from `packages/jupyter-env-mcp/`) and `jupyter` (upstream `datalayer/jupyter-mcp-server` pinned by rev+hash). Bundles a `python3.withPackages` JupyterLab with `jupyter-collaboration` (RTC), `ipykernel`, `jupyterlab-lsp`, and `python-lsp-server`, plus a generated `jupyter_lab_config.py` + `overrides.json` that forces the Dark theme and 60s autosave via `JUPYTER_CONFIG_PATH`. Both servers live outside the registry because they share lifecycle wiring. |
| `patches/mcp-libre-calc-and-write.patch` | Local patch applied to the `libreoffice` MCP server (`patrup/mcp-libre`, unmaintained upstream). Fixes `create_document(doc_type="calc")` so it produces a real empty xlsx/ods via openpyxl instead of a 0-byte `touch()`, and adds a new `write_spreadsheet_data` tool that writes 2D cell data to `.xlsx`/`.ods` (ods round-trips through openpyxl + `soffice --convert-to`). Wired in via the `patches` field of the registry entry. |
| `skills/` | Local skill subdirectories auto-collected by `claude.nix`. |

## Notable Configuration Details

- **Git identity**: Default user name and email come from `inputs.self.commonModules.user.userConfig`. Azure DevOps repos get a separate identity injected via a sops template at `~/.config/git/config-azure`, matched with `hasconfig:remote.*.url:https://dev.azure.com/**`.
- **Git Azure proxy**: HTTPS requests to `dev.azure.com` are routed through `socks5h://127.0.0.1:1080`.
- **Lazygit keybindings**: Extensively remapped (e.g., `i`/`e` for prev/next item, `n`/`o` for prev/next block, `h`/`H` for next/prev search match). This suggests a Colemak or similar non-QWERTY keyboard layout.
- **OpenCode provider**: Uses a custom `gl4f` provider pointing to `https://g4f.space/api/nvidia` with the MiniMax M2.1 model.
- **Claude Code skills**: No hashes are maintained — skill sources come from flake inputs (`anthropics-skills`, `vibekit`) or local paths, and every direct subdir of a root becomes a skill. Local names override upstream on collision because `extraSkills` and later `foldl'` entries win.
- **MCP git-sourced servers**: `mkGitServer` keys the writable workdir on a 12-char slice of the store-path hash of the (possibly patched) source, so both rev bumps *and* patch edits invalidate the cached copy. Current runtime support is `uv-run` only.
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
- **Git extension**: `programs.git.settings.extensions.worktreeConfig = true` is set in `git.nix` so ccmanager's per-worktree `ccmanager.parentBranch` storage activates. Upstream docs specify graceful degradation when the extension isn't in effect (file diffs still render; ahead/behind info omitted), so repos where git ignores the global don't break.
- **Shortcut**: `ccmgr` = `ccmanager --multi-project` (name-collision with claude-monitor's `ccm`).
- **Version**: `ccmanagerVersion = "latest"` matches the `ruflo-cli.nix` convention. Pin explicitly if upstream ships a breaking change to hook env var names (`CCMANAGER_*`).

## External Claude Code bundles (ruflo + wshobson/agents)

Two upstream resource packs are installed declaratively via `claude-resources.nix`:

- `inputs.ruflo` → pinned at `01070ede81fa6fbae93d01c347bec1af5d6c17f0` (flake = false)
- `inputs.wshobson-agents` → pinned at `27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb` (flake = false)

**Naming scheme** — filenames encode provenance so the flat `~/.claude/` namespace stays collision-free:

| Source | Example input path | Example installed name |
|---|---|---|
| ruflo agent | `ruflo/.claude/agents/core/coder.md` | `ruflo--core--coder.md` |
| ruflo command | `ruflo/.claude/commands/sparc/pipeline.md` | `ruflo--sparc--pipeline.md` |
| ruflo skill | `ruflo/.claude/skills/agentdb-router/` | `~/.claude/skills/ruflo--agentdb-router/` |
| wshobson agent | `wshobson-agents/plugins/backend-architect/agents/api-designer.md` | `wshobson--backend-architect--api-designer.md` |
| wshobson command | `wshobson-agents/plugins/devops/commands/deploy.md` | `wshobson--devops--deploy.md` |
| wshobson skill | `wshobson-agents/plugins/security-auditor/skills/owasp-top-10/` | `~/.claude/skills/wshobson--security-auditor--owasp-top-10/` |

**To bump** either bundle:

1. `nix flake lock --update-input ruflo` (or `wshobson-agents`)
2. If the ruflo npm CLI version changed, update `rufloVersion` in `ruflo-cli.nix`.
3. Update the pinned rev in the `inputs.<name>.url` line of `flake.nix` and the matching `rev:` line in `claude-kit.nix cmd_version`.

**`claude-kit` subcommands** — browse (`list`/`show`/`search`/`source`), execute (`run <slash-command>`), plugin management (`plugin install|uninstall|enable|disable|update|list`), marketplace (`marketplace list|add|remove`), MCP (`mcp …`), `doctor`, `version`. Run `claude-kit help` for the full menu.

**Alternative to flattening**: `wshobson/agents` ships its own marketplace manifest at `${inputs.wshobson-agents}/.claude-plugin/marketplace.json`. If you later prefer Claude Code's plugin manager, register it with `claude-kit marketplace add wshobson wshobson/agents` and install bundles via `claude-kit plugin install <name>@wshobson`.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is ultimately pulled into `modules/cross-platform/default.nix` for all platforms.
