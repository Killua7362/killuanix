# Dev Module

Home Manager module for development tools shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `git.nix`, `lazygit.nix`, `opencode.nix`, `claude.nix`, `claude-resources.nix`, `claude-kit.nix`, `ruflo-cli.nix`, `code-index.nix`, and `jupyter-env-mcp.nix`. |
| `git.nix` | Git configuration. Sets user identity from `commonModules.user.userConfig`. Includes a conditional include for Azure DevOps repos that swaps in Boeing credentials (decrypted via sops) and routes traffic through a SOCKS5 proxy at `127.0.0.1:1080`. |
| `lazygit.nix` | Lazygit configuration. Defines a full custom keybinding map covering universal navigation, file staging, branch operations, commits, stash, submodules, and merge conflict resolution. |
| `claude.nix` | Enables `programs.claude-code` and wires up both skills and MCP servers. Auto-collects every subdirectory under each entry in `skillRoots` (upstream `anthropics/skills` + local `./skills`) into `programs.claude-code.skills`, plus cherry-picked `extraSkills` (e.g. `er-diagram-and-data-modeling` from `vibekit`). MCP servers come from the registry at `modules/common/mcp-servers.nix`; catalog entries resolve to `natsukium/mcp-servers-nix` binaries, while git-sourced entries are wrapped by `mkGitServer`, which copies the (optionally patched) source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` so runtimes like `uv run` have a writable workdir. |
| `claude-resources.nix` | Flattens two external bundles into `~/.claude/{agents,commands,skills}/`: `ruvnet/ruflo` (108 agents + 168 commands + 41 skills) and `wshobson/agents` (184 agents + 98 commands + 150 skills across 78 plugins). Builds three derivations via `pkgs.runCommand` that copy the markdown with unique prefixes — `ruflo--<subpath>.md` and `wshobson--<plugin>--<name>.md` — since Claude Code's standalone `~/.claude/` tree is flat (no namespacing from nested dirs). Wires agents/commands via `home.file` with `recursive = true` (so user-created files are preserved), and merges skills into the existing `programs.claude-code.skills` attrset. Also exposes read-only source symlinks under `~/.cache/claude-kit/sources/`. |
| `claude-kit.nix` | Terminal utility (`claude-kit`) wrapping the resources installed above. Subcommands: `list`/`show`/`search`/`run`/`source` for browsing installed items; `plugin <install\|uninstall\|enable\|disable\|update\|list>` pass-through to `claude plugin …`; `marketplace <list\|add\|remove>` edits `~/.claude/settings.json` via `jq`; `mcp …` pass-through to `claude mcp …`; `ruflo …` pass-through to the ruflo CLI; plus `doctor` and `version`. Uses `fzf` + `bat` for search preview when on a TTY. |
| `ruflo-cli.nix` | Light `ruflo` CLI shim — a `writeShellApplication` that lazy-installs ruflo under `$XDG_CACHE_HOME/ruflo/` on first run via `npx --yes ruflo@<version>` using the existing `nodejs_20` package. No build-time npm closure; first invocation downloads, subsequent invocations are instant. Pinned `rufloVersion` string at the top of the file should be kept aligned with the `ruflo` flake-input rev. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |
| `code-index.nix` | Registers the custom `code-index` MCP server (built from `packages/code-index-mcp/` via uv2nix). Injects `QDRANT_URL_FILE`, `QDRANT_API_KEY_FILE`, and `NVIDIA_API_KEY_FILE` from sops secrets. Lives outside `mcp-servers.nix` because it needs secret paths the catalog/git-source schema doesn't model. |
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
