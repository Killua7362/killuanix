# AI Module

Home Manager module for AI coding tools — Claude Code (and its surrounding ecosystem of CLIs, resource bundles, and MCP servers), OpenCode, and the MCP servers wired into them. Shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `opencode.nix`, `claude.nix`, `claude-hooks.nix`, `claudio.nix`, `claude-resources/`, `claude-kit/`, `claude-launchers/`, `ruflo-cli.nix`, `claude-flow-cli.nix`, `ccr.nix`, `ccmanager.nix`, `code-index.nix`, `gitnexus-cli.nix`, `jupyter-env-mcp.nix`, `kindly-web-search.nix`, `freshrss-mcp/`, and `den/`. |
| `claude.nix` | Enables `programs.claude-code` and wires up skills and MCP servers. Local always-on skills live in `Notes/claude/skills/` (each subdir auto-discovered via `builtins.readDir` and surfaced into `~/.claude/skills/<name>` via `mkOutOfStoreSymlink`). User-defined slash commands live in `Notes/claude/commands/` (each `.md` auto-discovered into `~/.claude/commands/<file>.md` the same way). Content edits propagate instantly; *adding* a new dir/file requires `scripts/nix_switch` to re-evaluate `readDir`. `extraSkills` (still wired through `programs.claude-code.skills`) is the cherry-pick hook for individual upstream skills from flake inputs that should load everywhere; currently holds `gstack` (whole `inputs.gstack` tree → `~/.claude/skills/gstack/`) + `office-hours` (= `${inputs.gstack}/office-hours` → `~/.claude/skills/office-hours/`) + `plan-eng-review` (= `${inputs.gstack}/plan-eng-review`). Pairing is mandatory: both gstack sub-skills' SKILL.md preambles reference `~/.claude/skills/gstack/bin/...` and other sibling sub-skills, so the umbrella tree has to be present. MCP servers come from two sources, merged at module-eval time: (1) the registry at `modules/common/mcp-servers.nix` (catalog → natsukium binaries, gitSource → `mkGitServer`, npxDirect → `mkNpxDirectServer`, uvxDirect → `mkUvxDirectServer`); (2) the `local.extraMcpServers` option defined here as a side-channel for siblings that need `pkgs` / sops in scope (currently `code-index.nix`, `jupyter-env-mcp.nix`, `kindly-web-search.nix`). Hook entries follow the same side-channel pattern via `local.extraHooks` (`attrsOf (listOf attrs)`): every contributor file (`claudio.nix`, `claude-hooks.nix`, and the caveman Stop hook defined inline here) writes per-event lists, and a single aggregator in `claude.nix` folds them into `programs.claude-code.settings.hooks` — the `listOf` element type means same-event contributions from different files concat instead of clobbering. Both sources are filtered identically: entries with `optional = true` are **excluded** from `programs.claude-code.mcpServers` (so they don't load globally) but still appear in `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` — the resolved-catalog file consumed by `claude-kit project sync` to mirror stanzas into a project's `./.mcp.json` on demand. `enabledPlugins` is mostly per-project (opt in via `claude-kit lazy add plugin …`); the only globally-enabled plugin is `caveman@caveman` (token-compressed response style + Shrink MCP — see "Always-on plugins" below). Also wires the canonical Claude memory location: `~/.claude/CLAUDE.md` is a `mkOutOfStoreSymlink` to `Notes/claude/global.md`, and `~/.claude/projects/-home-killua-killuanix/memory` is a symlink to `Notes/claude/memory/`. **Overrides `programs.claude-code.package`** with a tiny wrapper (`overlayClaude` → `claudeWithOverlay`) that boots every `claude` invocation through a per-PID overlay config dir so `/effort medium\|auto\|low\|xhigh` works mid-session — see "## /effort overlay wrapper" below. |
| `claude/scripts/mcp-git-server.sh` | Wrapper body executed by Claude Code for git-sourced MCP servers. Reads `MCP_NAME` / `MCP_SRCKEY` / `MCP_SRC` / `MCP_RUNTIME` / `MCP_ENTRYPOINT` env vars (set by `mkGitServer` in `claude.nix`), copies the read-only nix-store source into `$XDG_CACHE_HOME/mcp-servers/<name>-<srcKey>/` on first run, and exec's the runtime. Currently only `uv-run` is supported; extending to `pipx-run`/`npm-run` means adding a case here, not in nix. |
| `claude-resources/` | Builds **one lazy sub-catalog per upstream source** under `Notes/claude/lazy/<source>/` — currently `ruflo`, `wshobson` (= `inputs.wshobson-agents`), `anthropics-skills`, `gstack`, and `glebis-claude-skills`. Was originally a single merged `upstream/` catalog; split so adding a new flake input means a new sibling folder rather than another row mixed into one tree. Directory layout: `default.nix` + `build/{flat-{ruflo,wshobson}-{markdown,skills},catalog,ruflo-bundles}.sh`. The `catalog.sh` script is shared and parameterised by `$NAME` / `$SKILLS_DIR` / `$AGENTS_DIR` / `$COMMANDS_DIR` (any dir may be unset → empty array). Each `runCommand` reads its bash body via `builtins.readFile` and passes nix-injected store paths through env vars. The activation script (`home.activation.lazyUpstreamCatalogSymlink`) lays down `Notes/claude/lazy/{ruflo,wshobson,anthropics-skills}/` symlinks and removes a legacy `upstream/` dir if a previous generation left one. **No longer installs into `~/.claude/`** — read-only symlinks under `~/.cache/claude-kit/sources/` (now per-source: `ruflo-catalog.link`, `wshobson-catalog.link`, `anthropics-skills-catalog.link`, plus the per-source flat-dir links) let `claude-kit` resolve store paths without globbing. See `claude-resources/CLAUDE.md`. |
| `claude-kit/` | Terminal utility (`claude-kit`) for browsing installed resources and managing the lazy catalog. Was a single 1282-line `.nix`; now a directory with `default.nix` (small `writeShellApplication` wrapper that bundles `scripts/` via `runCommand` and sets `CLAUDE_KIT_LIB_DIR` + `CLAUDE_KIT_PLAN_BIN`) + `scripts/claude-kit.sh` (entrypoint dispatcher) + `scripts/lib/{common,lazy,session}.sh` + `scripts/cmd/<name>.sh` (one per public subcommand) + `scripts/cmd/lazy/<name>.sh` (one per `lazy` verb, with `bundle.sh` internally dispatching the bundle subverbs) + `plan/` (uv2nix-built python sidecar for `claude-kit plan` — two-stage prompt-to-plan tool using `claude-agent-sdk` with the user's local Claude Code auth). See `claude-kit/CLAUDE.md`. Subcommand surface: `list`/`show`/`search`/`run`/`plan`/`source`/`clean`/`resume`/`doctor`/`version`; `lazy …` (`ls`/`show`/`add`/`rm`/`project`/`new`/`refresh`/`doctor` plus `bundle ls\|show\|add\|rm\|status`); `plugin`/`marketplace`/`mcp`/`ruflo` passthroughs. Uses `fzf` + `bat` for search preview when on a TTY. |
| `claude-launchers/` | Sister wrappers around `claude` that boot Claude Code with curated extra resources layered on top of the global config — and **isolated** from project-level Claude config in cwd ancestors. One launcher per file (auto-discovered by `claude-launchers/default.nix`); each file is a function returning the full attr set with every supported option (`inheritGlobal`, `skills`/`agents`/`commands`/`plugins`/`mcp`, `excludeSkills`/etc., `allowedTools`/`deniedTools`, `hooks`, `restrictToDirs`, `model`/`effort`) listed explicitly so the surface is self-documenting. Currently ships `claude-algo` (default `inheritGlobal = true`, adds `inputs.algo-sensei`), `claude-news` (`inheritGlobal = false`, lean MCP set + restrictToDirs pinning to `~/killuanix/Notes`), and `claude-discover` (registry finder — `inheritGlobal = false`, MCP set `[ "kindly-web-search" "fetch" "basic-memory" ]`, loads the `discover-resource` skill from `Notes/claude/lazy/personal/skills/`, ships `/find <use-case>` to search the official MCP registry + Glama + PulseMCP + anthropics/skills + wshobson/agents + davila7/claude-code-templates + ruvnet/ruflo + anthropics/claude-plugins-official + VoltAgent/awesome-claude-code-subagents). See [`claude-launchers/CLAUDE.md`](./claude-launchers/CLAUDE.md) for the full attribute reference and mechanism. |
| `ruflo-cli.nix` | Light `ruflo` CLI shim — a `writeShellApplication` that lazy-installs ruflo under `$XDG_CACHE_HOME/ruflo/` on first run via `npx --yes ruflo@<version>` using the existing `nodejs_20` package. No build-time npm closure; first invocation downloads, subsequent invocations are instant. Pinned `rufloVersion` string at the top of the file should be kept aligned with the `ruflo` flake-input rev. |
| `claude-flow-cli.nix` | Companion shim for `claude-flow` (= `npx --yes @claude-flow/cli@<version>`). Same lazy-install pattern as `ruflo-cli.nix` but for the runtime CLI invoked by `ruflo init`'s post-init guidance (`claude-flow daemon start`, `memory init`, `swarm init`, `init --start-all`) and by the `.mcp.json` server entry that `ruflo init` writes. Cache lives under `$XDG_CACHE_HOME/claude-flow/`. Pinned `claudeFlowVersion` should track `rufloVersion` in the sibling shim. |
| `ccr.nix` | Claude Code Router — Node daemon (lazy-`npx`) on `127.0.0.1:3456` that re-translates the Anthropic wire format to OpenAI-compatible providers. Configures NVIDIA NIM routing via a sops-rendered `~/.claude-code-router/config.json` (CCR can't read keys from a path) and runs as a `systemd.user.services.ccr` always-on daemon on Linux (manual `ccr start` on macOS). Routing is **opt-in per invocation**: use `ccr code` to launch Claude Code through CCR. Plain `claude`/`ruflo`/`claude-flow`/ccmanager hit the real Anthropic API — no global `ANTHROPIC_BASE_URL` is set. |
| `claude-powerline.nix` | Declarative Claude Code status line (replaced `ccstatusline.nix` to drop per-refresh Node startup cost). Lazy-compiles `@owloops/claude-powerline@<pinned>` into a Bun-native single binary on first run via `bun build --compile --minify --target=bun`; the result is cached at `$XDG_CACHE_HOME/claude-powerline/bin-v<version>/claude-powerline` and exec'd directly on every subsequent render (~5-20ms vs the old node+npx ~200-400ms). Version bumps land in a new sub-dir so the old binary GCs by `rm -rf $XDG_CACHE_HOME/claude-powerline/`. `xdg.configFile."claude-powerline/config.json"` is rendered from a Nix attrset (read-only nix-store symlink). Wired into `programs.claude-code.settings.statusLine` in `claude.nix` via `command = "claude-powerline"` (PATH lookup, so `claude-launchers/` wrappers inherit it). Default layout is one line of `minimal`-style segments: `model · thinking · context · git · directory · block` — the five carried over from ccstatusline plus `block`, which reads the `rate_limits` field from Claude Code's stdin payload and renders `◱ NN% (Xh Ym)` to mirror claude.ai's usage-reset timer (Pro/Max only; silently empty for raw-API or CCR-routed sessions). Colours come from `config.theme.palette` via `colors.custom.<segment>.{bg,fg,bold}` under `theme = "custom"`. The `minimal` style has no glyph between segments — flip `display.style` to `"tui"` and set `display.tui.separator.column = " │ "` if the explicit `│` divider is wanted back. |
| `ccmanager.nix` | Installs [kbwo/ccmanager](https://github.com/kbwo/ccmanager) (TUI for juggling multiple Claude Code sessions across git worktrees) using the same lazy-`npx` pattern as `ruflo-cli.nix`. Ships `ccmanager`, the `ccmgr` shortcut (= `ccmanager --multi-project`; `ccm` is taken by claude-monitor), and two worktree-hook binaries (`ccmanager-pre-creation-dedupe`, `ccmanager-post-creation-copy-staged`). Declaratively writes `~/.config/ccmanager/config.json` (read-only — TUI edits won't persist). Drives the `~/ccmanager-projects/` farm used by `--multi-project` from the `ccmanagerProjects` attrset at the top of the file — on Linux each entry becomes a `bindfs` FUSE mount managed by a systemd user service, on macOS it falls back to symlinks. See "## CCManager wiring" below. |
| `claudio.nix` | Builds [ctoth/claudio](https://github.com/ctoth/claudio) v1.13.1 (Go binary via `buildGoModule`) and wires it as a Claude Code hook for `PreToolUse` / `PostToolUse` / `UserPromptSubmit` events via the shared `local.extraHooks` side-channel declared in `claude.nix` (so it co-exists with the caveman Stop hook and `claude-hooks.nix` for the same events). claudio reads the full hook payload on stdin, parses the tool/command (knows git, npm, docker, cargo, go, pip, yarn, kubectl, …), and plays a contextual sound via a fallback chain (`success/git-commit-success.wav` → `success/git-success.wav` → `success/bash-success.wav` → `success/success.wav` → `default.wav`). With no soundpack configured it uses platform built-ins (macOS system sounds, Windows Media under WSL via `/mnt/c/`, basic fallback on plain Linux — pipewire's ALSA shim on chrollo/killua works out of the box). malgo links `-ldl -lpthread -lm` only on Linux and dlopens libasound/libpulse at runtime, so no extra `buildInputs` are needed. Silence without rebuilding: `export CLAUDIO_ENABLED=false` in the shell launching claude. The upstream `claudio install` subcommand (which mutates `~/.claude/settings.json`) is unused — hooks are registered declaratively. Bumping the version means flipping both `vendorHash` and the `src` hash to `lib.fakeHash`, running `scripts/nix_switch`, and pasting the real hashes from the failure back in. |
| `claude-hooks.nix` | Wires [johnlindquist/claude-hooks](https://github.com/johnlindquist/claude-hooks) — TypeScript-powered hook handlers with full type safety on the 7 Claude Code hook payloads (`Notification`, `Stop`, `PreToolUse`, `PostToolUse`, `SubagentStop`, `UserPromptSubmit`, `PreCompact`). Upstream is a per-project `npx claude-hooks` scaffolder that writes `./.claude/hooks/{index,lib,session}.ts` + merges 7 hook entries into `./.claude/settings.json`. We can't run that verbatim — `~/.claude/settings.json` is a read-only nix-store symlink — so instead the TS files live under `Notes/claude/hooks/` (live-editable in Obsidian, same `mkOutOfStoreSymlink` pattern as `Notes/claude/skills/` and `Notes/claude/commands/`) and surface into `~/.claude/hooks/`. Hook commands (`bun ~/.claude/hooks/index.ts <Event>`) are registered through the shared `local.extraHooks` side-channel — co-exists cleanly with claudio (Pre/PostToolUse/UserPromptSubmit) and the caveman Stop hook (claude.nix). `pkgs.bun` is added to `home.packages` so the hook subprocess Claude Code spawns finds the runtime on PATH. Edits to `Notes/claude/hooks/index.ts` apply on the next `claude` session — no rebuild. Adding/removing files in `Notes/claude/hooks/` also needs no rebuild (we symlink the directory). To re-seed `lib.ts` / `session.ts` from upstream after an upstream payload-type bump: `cd /tmp/seed && npx claude-hooks && cp -r .claude/hooks/* ~/killuanix/Notes/claude/hooks/`. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |
| `code-index.nix` | Registers the custom `code-index` MCP server (built from `packages/code-index-mcp/` via uv2nix). Points `QDRANT_URL` at the local quadlet container (`http://127.0.0.1:6333`, see `modules/containers/qdrant.nix` — no API key on the local instance) and injects `NVIDIA_API_KEY_FILE` from sops. Lives outside `mcp-servers.nix` because it needs a secret path the catalog/git-source schema doesn't model — registers via `local.extraMcpServers.code-index` (the side-channel option declared in `claude.nix`) with `optional = true`, so it only loads in projects whose `claude-kit.nix` opts in via `mcp = [ "code-index" ]`. Indexed file types: `.java` (AST-chunked via tree-sitter), `.properties` (one chunk per key, handles `#`/`!` comments and backslash continuations — ATG `$class`/`$scope` keys fall out naturally), `.xml` (whole-file chunk keyed on the file stem). Extend `LANGUAGE_EXTENSIONS` + the dispatch in `_do_index` in `server.py` to add more. Companion `gitnexus` MCP (npm `gitnexus@latest`, stdio `gitnexus mcp`) lives in `modules/common/mcp-servers.nix` via the npxDirect lane (also `optional = true`) — it builds a per-repo Tree-sitter knowledge graph at `<repo>/.gitnexus/` (after `gitnexus analyze`) and answers relational queries (impact, call graphs, process tracing) that complement code-index's vector search rather than duplicating it. The `qdrant_cluster_endpoint` / `qdrant_api_key` entries in `modules/common/sops.nix` are now unreferenced (left in place for historical context; safe to remove). |
| `gitnexus-cli.nix` | Light `gitnexus` CLI shim — `writeShellApplication` lazy-installing `gitnexus@<pinned>` under `$XDG_CACHE_HOME/gitnexus/{npm-cache,npm-prefix}` via `npx --yes`, mirroring `ruflo-cli.nix`. Cache namespace is shared with the `gitnexus` MCP entry in `modules/common/mcp-servers.nix` (`cacheNamespace = "gitnexus"`, same trick as the `claude-flow ↔ ruflo` pair documented there) so Claude Code's MCP connect probe doesn't pay a second cache resolution on cold start. CLI surface includes `analyze` (build per-repo index → `<repo>/.gitnexus/`, gitignored globally via `programs/dev/git.nix`), `list`, `status`, `clean`, `mcp`, plus `serve` (HTTP UI on :4747, run manually if desired) and `wiki` (LLM-generated docs, needs `OPENAI_API_KEY`, not wired). Upstream is **PolyForm Noncommercial** — fine for personal/dev use. `gitnexus analyze` must run once per repo before the MCP returns useful results; `~/.gitnexus/registry.json` is the global pointer file. |
| `jupyter-env-mcp.nix` | Registers two cooperating Jupyter MCP servers: `jupyter-env` (local server built from `packages/jupyter-env-mcp/`) and `jupyter` (upstream `datalayer/jupyter-mcp-server` pinned by rev+hash). Bundles a `python3.withPackages` JupyterLab with `jupyter-collaboration` (RTC), `ipykernel`, `jupyterlab-lsp`, and `python-lsp-server`, plus a generated `jupyter_lab_config.py` + `overrides.json` that forces the Dark theme and 60s autosave via `JUPYTER_CONFIG_PATH`. Both servers live outside the registry because they share lifecycle wiring — registered via `local.extraMcpServers.{jupyter-env,jupyter}` (the side-channel option in `claude.nix`) with `optional = true` so they only load in projects whose `claude-kit.nix` opts in via `mcp = [ "jupyter-env" "jupyter" ]`. |
| `freshrss-mcp/` | Registers the `freshrss` MCP server — a tiny Greader-API client over the local FreshRSS container (`modules/containers/freshrss/`, http://localhost:8083). `server.py` is a single-file Python script with PEP 723 inline metadata (`mcp` + `httpx`), launched via `uv run --quiet --script`; uv resolves the dep set on first call and caches under `$XDG_CACHE_HOME/mcp-freshrss/uv-cache`. Tools: `list_unread`, `list_starred`, `search`, `list_feeds`, `items_from_feed`, `list_categories`, `mark_read`, `star`. Auth uses the FreshRSS **API password** (`freshrss_admin_api_password` from sops — a duplicate of the system-side key in `sops-system.nix`, declared on the HM side in `modules/common/sops.nix` so the user-space MCP can read it). Registers via `local.extraMcpServers.freshrss` (side-channel) with `optional = true` — does NOT load in every Claude Code session; the only place it activates by default is the `claude-news` launcher (`claude-launchers/`), which lists `mcp = [ "freshrss" "fetch" "basic-memory" ]` and resolves it from `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` at launch. Other projects can opt in via `claude-kit lazy add mcp freshrss`. The matching slash commands (`/digest`, `/ask-news`, `/starred`) live in `Notes/claude/lazy/personal/commands/` (NOT auto-discovered globally — only loaded inside `claude-news` via the launcher's `commands = { digest = notesCmd "digest"; ... }` block, which symlinks the live Notes paths into the launcher state dir). Content edits propagate without `scripts/nix_switch`. Refresh the personal lazy catalog with `claude-kit lazy refresh personal` if you want them browsable via `claude-kit lazy ls`. |
| `oracle-sqlcl-mcp.nix` | Registers the `oracle-sqlcl` MCP server — Oracle SQLcl's **built-in** MCP server (SQLcl >=25.1, started via `sqlcl -mcp`). Exposes saved SQLcl connections (`~/.dbtools/connections.json`) as MCP tools. No separate npm/PyPI package — the wrapper is just `exec sqlcl -mcp "$@"`. nixpkgs renames the launcher to `sqlcl` (avoids clashing with GNU parallel's `sql`); `pkgs.sqlcl` bundles its own JRE. Lives outside `mcp-servers.nix` because the sqlcl store path needs `pkgs` in scope — registers via `local.extraMcpServers.oracle-sqlcl` (side-channel declared in `claude.nix`) with `optional = true`. Loads only in projects that opt in via `claude-kit.nix:mcp = [ "oracle-sqlcl" ]`. Intended pairing with `bastion-sql` (`modules/common/programs/cloud/azure-bastion/`): tunnel forwards `127.0.0.1:1521 → 10.55.46.132:1521`, user saves a SQLcl connection (`sqlcl /nolog` then `connect -save <name> -savepwd <user>/<pass>@127.0.0.1:1521/beastg<N>`), and the MCP server lets Claude run queries by connection name. |
| `kindly-web-search.nix` | Registers the `kindly-web-search` MCP server ([Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server](https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server)) — web search + page-content extraction tuned for AI coding agents. Lazy-resolved via `uvx --from git+<url>` (cache under `$XDG_CACHE_HOME/mcp-kindly/uv-cache`); no rev pin, so uv resolves HEAD on cache miss (append `@<sha>` to the URL to pin). Backed by the local SearXNG container (`SEARXNG_BASE_URL = http://localhost:8888/`, see `modules/containers/searxng.nix`) — no API signup required. `KINDLY_BROWSER_EXECUTABLE_PATH` points at `pkgs.chromium`/bin/chromium for the headless-browser `page_content` extraction (same chromium build mermaid's puppeteer uses). Lives outside `mcp-servers.nix` because the chromium store path needs `pkgs` in scope — registers via `local.extraMcpServers.kindly-web-search` (side-channel declared in `claude.nix`) with `optional = true`, so it only loads in projects whose `claude-kit.nix` opts in via `mcp = [ "kindly-web-search" ]` (or `claude-kit lazy add mcp kindly-web-search` outside a den project). |
| `libreoffice-mcp-launcher.nix` | Ships `soffice-mcp` — a thin `writeShellApplication` wrapper around `soffice` that opens a UNO `--accept=` socket on `localhost:2002`, waits for it to come up, then calls `createInstanceWithContext("org.mcp.libreoffice.MCPExtension")` over the UNO bridge to force LO to import the extension's python module. The patched module's auto-start thread then binds the in-process MCP HTTP server on `:8765`. Required because bare `soffice` doesn't load the extension's python module on startup (LO defers it to first dispatch query, and upstream's `ProtocolHandler.xcu` routing is broken — `service:org.mcp.libreoffice.MCPExtension*` URLs resolve to LO's built-in `ServiceHandler` stub rather than the extension's `MCPProtocolHandler`, so menu/toolbar clicks silently no-op). `pkgs.libreoffice.unwrapped/lib/libreoffice/program` is used directly for `PYTHONPATH`/`LD_LIBRARY_PATH`/`URE_BOOTSTRAP` because pyuno bindings (`uno.py`, `libpyuno.so`) live in the unwrapped derivation. Wired into the dev/ai aggregator via `default.nix`; appears as `home.packages` so the binary is on `PATH`. |
| `patches/mcp-libre-add-fastmcp-dep.patch` | Local patch applied to the `libreoffice` MCP server (`jwingnut/mcp-libre`). Upstream's `pyproject.toml` lists `httpx` / `mcp[cli]` / `pydantic` but forgets `fastmcp` — the bridge script `libreoffice_mcp_server.py` imports `from fastmcp import FastMCP`, so without this patch `uv run` resolves a venv that fails with `ImportError: No module named 'fastmcp'` on every startup. Wired in via the `patches` field of the registry entry in `modules/common/mcp-servers.nix`. |
| `patches/mcp-libre-extension-autostart.patch` | Local patch applied to the `.oxt` LibreOffice extension half of `jwingnut/mcp-libre` (`plugin/pythonpath/registration.py`). Spawns `_start_server` in a daemon thread at module-import time so the in-process MCP HTTP server on `:8765` binds as soon as LO loads the python module — paired with the `soffice-mcp` wrapper (`libreoffice-mcp-launcher.nix`) that forces module load on every launch. Idempotent: `_start_server` is guarded by `_lock` + `_server_started`. Patch is **not** applied via `mkGitServer`'s `patches` field (the extension is not built by nix — it's built manually with `plugin/build.sh` and installed via `unopkg add`); it's applied to the upstream clone with `patch -p1` before running `build.sh` (see the "LibreOffice MCP extension" section of the root `CLAUDE.md` post-install). |
| `den/` | `den` — project-scoped symlink + patch manager. Was a single 2944-line `.nix`; now a directory with `default.nix` (HM module + `runCommand` bundling) + `scripts/den.sh` (entrypoint sourcing all libs/cmds eagerly + dispatching to `den_cmd_<name>`) + `scripts/lib/{common,meta,bindings,store,hooks,generations,devshell}.sh` + `scripts/cmd/<name>.sh` (one per subcommand, ~34 files; `re-add.sh`, `last-applied.sh` use hyphenated filenames; functions use underscores via `den_cmd_<name>`) + `helper/main.py` (argparse dispatcher) + `helper/lib/{toml_io,ignore,manifest}.py` + `helper/cmd/{walk,manifest_hash,status,jsonl,toml}.py`. Wrapper sets `DEN_LIB_DIR`, `DEN_HELPER_BIN`, and `DEN_DEV_TEMPLATES_DIR` (= `inputs.dev-templates`, pinned `the-nix-way/dev-templates`) env vars; the python sidecar is wired via `sys.path.insert(0, "${denHelperLib}")` in a tiny `writePython3Bin` entry stub. Bash CLI binds named projects under `Notes/projects/<NAME>/` to working directories via symlinks. Two-tier metadata: `Notes/projects/<NAME>/.den-project.toml` (project marker, pushed) + `<bound-cwd>/.den-meta.json` (host-side, globally gitignored via `programs/dev/git.nix`). Hybrid manifest (auto-walk `files/`; `manifest.toml` only for entries needing metadata). `den new --devshell <lang>` (or the interactive prompt on TTY) seeds the project with a `dev-templates` flake + `.envrc` and auto-runs `direnv allow`; `nix-direnv` is enabled in `modules/common/programs.nix:33`. Linux-only. See `## den` below and `den/CLAUDE.md`. |

## Notable Configuration Details

- **OpenCode provider**: Uses a custom `gl4f` provider pointing to `https://g4f.space/api/nvidia` with the MiniMax M2.1 model.
- **claude-kit cache prune**: `~/.cache/claude-kit/{sessions,sources}` is pruned daily (>7 days old) by the Cronicle event defined in `modules/containers/cronicle/events/claude-kit-prune.nix`. Set `enabled = false` in that file to grey it out in Cronicle (event stays visible, Active checkbox off). Transient pause without a rebuild: toggle the UI's "Active" checkbox at http://localhost:3012 — sticky as long as nix's `enabled` stays true. The `/tmp/claude-kit-*` working dirs are still cleaned at script exit by traps inside `claude-kit/scripts/`.
- **Embedded-script extraction pattern**: `claude-resources/`, `claude-kit/`, `den/`, and `claude/scripts/mcp-git-server.sh` follow a single convention — bash bodies live as plain `.sh` files (with `#!/usr/bin/env bash` shebangs, real shellcheck), python bodies as plain `.py` files, both bundled into the store via `pkgs.runCommand "name" {} '' cp -r ${./scripts}/* $out/ ''`. The `writeShellApplication` (or `runCommand`) wrapper does **only one job**: set env vars for any nix-injected values (store paths, version pins, config strings) and `exec bash $LIB_DIR/entry.sh "$@"`. **No `${nix}` interpolation inside `.sh`/`.py`** — every nix-side value enters the script as `$ENV_VAR`. This keeps a shell/python LSP fully functional inside the source files. New per-script directives (`# shellcheck disable=…`, `# noqa: …`) live inline rather than as `excludeShellChecks` / `flakeIgnore` on the wrapper. Threshold for extraction is ~20 lines of embedded body; smaller wrappers (e.g. `mkNpxDirectServer`/`mkUvxDirectServer` in `claude.nix`) stay inline.
- **Claude Code skills**: No hashes are maintained. Two registration paths feed `~/.claude/skills/`:
  1. **Live, always-on, hand-authored** — each subdir of `Notes/claude/skills/` is auto-discovered in `claude.nix` (single `builtins.readDir` + `lib.mapAttrs'` block) and wired via `mkOutOfStoreSymlink`. Edit in Obsidian or any editor; no nix_switch needed for content edits. Currently just `memory-load`. Add a new one by dropping the dir into `Notes/claude/skills/<new>/SKILL.md` and running `scripts/nix_switch` (readDir re-evaluates and emits the new symlink). Same auto-enumeration applies to `Notes/claude/commands/*.md` for user-defined slash commands.
  2. **Nix-store-pinned, always-on, cherry-picked from flake inputs** — `extraSkills` in `claude.nix` (e.g. `foo = "${inputs.bar}/.../foo"`). Currently holds the `gstack` umbrella + `office-hours` + `plan-eng-review` (the umbrella is needed because those sub-skills' SKILL.md references `~/.claude/skills/gstack/bin/...`). Anything added here is passed through `programs.claude-code.skills = extraSkills` and requires `scripts/nix_switch` to update.
  3. **Project-opt-in, lazy** — upstream bundles (`anthropics/skills`, `ruflo`, `wshobson`) and personal lazy skills (`code-search`, `code-exploration`, `excalidraw-sketches`, `mermaid-diagrams`, `obsidian-vault`, `obsidian-clipper`) live in `Notes/claude/lazy/{upstream,personal}/skills/`. Added per-project via `claude-kit lazy add skill <name>` or `claude-kit.nix:skills = [ ... ]`.

  On name collision, the local always-on symlinks win (HM activation refuses to overwrite an existing `~/.claude/skills/<name>` from `programs.claude-code.skills` if it's already a `home.file` symlink).
- **MCP git-sourced servers**: `mkGitServer` keys the writable workdir on a 12-char slice of the store-path hash of the (possibly patched) source, so both rev bumps *and* patch edits invalidate the cached copy. Current runtime support is `uv-run` only.
- **MCP `uvxDirect` shape**: same pattern as `npxDirect` but for Python/PyPI packages. `uvx <package>` resolves and caches at first call under `$UV_CACHE_DIR=$XDG_CACHE_HOME/<cacheNamespace>/uv-cache`. Used by the `basic-memory` registry entry (markdown-backed knowledge graph MCP pointed at `Notes/claude/memory/`).
- **`optional = true` on an MCP entry**: excludes that server from `programs.claude-code.mcpServers` (no global wiring → not loaded in every project's Claude Code startup blob). Resolved stanza still appears in `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` (a HM-managed read-only catalog) so `claude-kit project sync` can mirror it into a project's local `./.mcp.json` when that project's `claude-kit.nix` declares `mcp = [ "name" ]`. Applies uniformly to registry entries (in `mcp-servers.nix`) and to side-channel entries via `local.extraMcpServers` (declared in `claude.nix` for siblings needing `pkgs`/sops in scope). Current opt-ins: `claude-flow` (needs `ruflo init`), `gitnexus` (needs `gitnexus analyze`), `excalidraw` (binds :3031), `libreoffice` (needs .oxt extension installed + soffice running with MCP server started), `mermaid` (puppeteer + chromium, niche per project), `code-index` (needs per-repo Qdrant indexing), `jupyter` + `jupyter-env` (run server lifecycle), `kindly-web-search` (cold-cache uvx resolve + headless chromium). Globally-loaded MCPs (no `optional` flag): `basic-memory`, `fetch`, `filesystem`, `memory`, `sequential-thinking`. Add `optional = true` to any other entry whose runtime cost or per-project setup means it shouldn't load everywhere.
- **`local.extraMcpServers`** (declared in `claude.nix`): side-channel option for MCP server stanzas that can't live in `mcp-servers.nix` (which has no `pkgs` / sops in scope). Shape: `{ <name> = { command = "..."; env = {...}; optional = true|false; }; }`. Pre-resolved — claude.nix passes these through `// (lib.mapAttrs (_: v: builtins.removeAttrs v ["optional"]) ...)` after filtering, so the `optional` field is stripped before reaching Claude Code's runtime config. Mirror the registry's filter semantics so optional/non-optional behaviour is uniform across both registration paths.
- **Claude memory canonical store**: `Notes/claude/global.md` and `Notes/claude/memory/` are the single source of truth. The Notes submodule is committed and pushed; `obsidian-git` auto-intervals are intentionally 0, so commits happen via the Obsidian command palette. The `memory-load` local skill (in `Notes/claude/skills/memory-load/`) describes how to retrieve memories on demand by trigger keyword instead of always-injecting them; the `basic-memory` MCP exposes `search_notes`, `read_note`, `edit_note` (prefer `append`/`replace_section` over `find_replace` against YAML frontmatter), `write_note`, `build_context`, `list_directory` against the same directory.
- **MCP registry patching**: Registry entries may set `patches = [./path/to.patch]`; `mkGitServer` runs `pkgs.applyPatches` before copying into the cache. Used by the `libreoffice` entry (`patches/mcp-libre-add-fastmcp-dep.patch` adds the missing `fastmcp` dep to upstream's `pyproject.toml`).
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

`claude-launchers/` provides Claude Code wrappers with extra resources scoped to that launcher only, **isolated** from any project-level Claude config in cwd ancestors. Full attribute reference, mechanism, and per-launcher rationale live in [`claude-launchers/CLAUDE.md`](./claude-launchers/CLAUDE.md). One launcher per file in that dir; `default.nix` auto-discovers every `*.nix` sibling. Currently ships `claude-algo`, `claude-news`, and `claude-discover`.

## /effort overlay wrapper

`~/.claude/settings.json` is a HM symlink into the read-only nix store. Claude Code's `/effort medium|auto|low|xhigh` open the file `O_RDWR` to mutate-in-place and hit `EACCES` before they touch JSON. (`/effort max` works because Claude treats `max` as a transient session boost; `/model` works because it writes to `~/.claude.json` — a separate file mode 0600, not nix-managed.)

`claude.nix` ships an `overlayClaude` `writeShellApplication` and a `claudeWithOverlay` `runCommand` that mirrors upstream's tree (`cp -as`) and swaps `bin/claude` for the overlay; this is then assigned to `programs.claude-code.package`. Behaviour:

- Every `claude` boot:
  - **No CLAUDE_CONFIG_DIR pre-set** → mktemp a per-PID dir under `${XDG_RUNTIME_DIR:-/tmp}/claude-session.XXXXXX`, mirror every entry of `~/.claude/` as symlinks *except* `settings.json` (copied in as a writable real file via `install -m 0644`) and the entries in `caveman_skip_symlink` (`.caveman-active`, `.caveman-statusline-suffix`), then `$HOME/.claude.json` (auth + onboarding state — sibling of `~/.claude/`, **not** inside it; without this every launch lands in re-auth) is symlinked into the dir, `CLAUDE_CONFIG_DIR=<state_dir>` exported, and a backgrounded `inotifywait -m -e close_write,moved_to` watcher on the overlay mirrors `.credentials.json` back to `~/.claude/.credentials.json` on every change (defends mid-session refresh: Claude's atomic `tmp + rename` replaces the inbound symlink with a real file in the overlay, so subprocesses — MCP servers, hooks, helpers — that read the canonical `~/.claude/.credentials.json` direct rather than via `$CLAUDE_CONFIG_DIR` would otherwise hit a 401 → mid-session re-login prompt); an EXIT/INT/TERM/HUP trap kills the watcher, does a final copy-back of `.credentials.json` (defensive — covers the race where the session ends before inotify drains its event queue; the next launch would otherwise read the stale expired token → forced re-login every session), and then `rm -rf`'s the dir. The caveman files are *neither symlinked nor pre-copied* — caveman-activate.js creates `.caveman-active` fresh inside the overlay on SessionStart, and the Stop hook (see "Stop hook — per-session statusline savings badge" under "## Always-on plugins") writes `.caveman-statusline-suffix` after each assistant turn. Per-session isolation depends on these files staying inside the overlay — symlinking the suffix through would let every concurrent claude process's Stop hook write through to one shared real file, and every session's badge would render the same number. Symlinking `.caveman-active` would additionally block caveman-activate.js's `safeWriteFlag` (caveman-config.js:122-141 — defence against attacker pointing the flag at `~/.ssh/id_rsa`), and the statusline would never show any `[CAVEMAN]` badge.
  - **CLAUDE_CONFIG_DIR already set** (caller is `claude-launchers/`'s `claude-algo`, or any future launcher) → leave the dir alone; just rewrite its `settings.json` from a read-only symlink-into-store into a writable copy. One conditional handles both code paths so launchers don't duplicate logic.
- Effects: `/effort medium` mutates the overlay copy. The nix-managed `~/.claude/settings.json` is never touched. Each new `claude` launch gets a fresh copy of declarative defaults — effort changes are strictly session-scoped.
- Per-PID dirs (not a single shared `$XDG_STATE_HOME/claude-session/`) so concurrent `claude` instances under ccmanager don't clobber each other.
- Anything Claude writes to `$CLAUDE_CONFIG_DIR/<entry>` for any other entry (sessions, projects, todos, file-history, …) flows through the symlink back to `~/.claude/<entry>` and persists normally.
- `claudeWithOverlay` `inherit (pkgs.claude-code) version meta;` so `claude --version`, claude-powerline's model segment, and any consumer reading `cfg.finalPackage.{version,meta}` stay accurate. HM still re-wraps the result with its own outer `--plugin-dir` shell wrapper at activation time — that wrapper calls our overlay (as `.claude-wrapped`), which in turn execs `${pkgs.claude-code}/bin/claude` (the upstream sadjow build). Three-deep wrapper chain.

To verify after `scripts/nix_switch`: `claude` → at the prompt run `/effort medium` (no EACCES); in another shell `ls -la /run/user/$(id -u)/claude-session.*/settings.json` (real file, not a symlink); `readlink -f ~/.claude/settings.json` (still a `/nix/store/...` path — declarative source untouched).

## Lazy resource catalog

Upstream resource bundles (ruflo + wshobson/agents + anthropics/skills) used to be flattened into `~/.claude/{agents,commands,skills}/` and listed in Claude Code's startup blob on every session — a major token-cost driver. Now they're in a **lazy catalog** under `Notes/claude/lazy/`, with **one sub-catalog per upstream source**, opted into per-project via `claude-kit lazy`.

### Layout

```
Notes/claude/lazy/
├── lazy.json                  # optional metadata; sub-catalogs are auto-discovered
├── ruflo/                     # nix-managed; do not hand-edit
│   ├── catalog.json           # symlink → /nix/store/.../catalog.json
│   └── bundles/ruflo.json     # 8-plugin ruflo stack
├── wshobson/                  # nix-managed; do not hand-edit
│   └── catalog.json
├── anthropics-skills/         # nix-managed; do not hand-edit
│   └── catalog.json
├── gstack/                    # nix-managed; do not hand-edit
│   └── catalog.json           # single monolithic `gstack` skill (whole garrytan/gstack tree)
├── personal/                  # hand-curated; edit in Obsidian
│   ├── catalog.json           # regenerate via `claude-kit lazy refresh personal`
│   ├── skills/<name>/SKILL.md
│   ├── agents/<name>.md
│   └── commands/<name>.md
└── <user-catalog>/            # `claude-kit lazy new <name>` scaffolds this
```

The tree is exactly **one level deep**. Any subdir with `catalog.json` is auto-discovered as a sub-catalog.

### Source bundles in the catalog

Each upstream source has its own sibling sub-catalog. The outer `ruflo--` / `wshobson--` prefixes from the legacy merged-`upstream/` catalog are dropped now that the catalog name disambiguates.

| Source | Pinned in `flake.nix` | Sub-catalog | Naming inside catalog |
|---|---|---|---|
| `inputs.ruflo` | `01070ede81fa6fbae93d01c347bec1af5d6c17f0` | `ruflo` | `<subpath-with-slashes-as-dashes>` |
| `inputs.wshobson-agents` | `27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb` | `wshobson` | `<plugin>--<basename>` |
| `inputs.anthropics-skills` | flake input | `anthropics-skills` | upstream name (already flat) |
| `inputs.gstack` | `b03cd1ae2dbe0c3a7fa770a52aeabb3b0c4f8c53` | `gstack` | single `gstack` skill — whole tree wrapped under `skills/gstack/` (sub-skills reference `~/.claude/skills/gstack/bin/...`) |
| `inputs.glebis-claude-skills` | floating `main` | `glebis-claude-skills` | upstream name unchanged (60+ flat skill dirs at repo root; `.claude-plugin/` marketplace manifest filtered out by the per-source flat builder) |

**To bump** any source:

1. `nix flake lock --update-input <name>`
2. If the ruflo npm CLI version changed, update `rufloVersion` in `ruflo-cli.nix`.
3. Update the matching `rev:` line in `claude-kit.nix cmd_version`.

The affected sub-catalog regenerates on the next `nix_switch` — no further action.

**To add a new upstream source** (= a new sibling folder under `Notes/claude/lazy/`):

1. Add the flake input in the repo root `flake.nix`.
2. In `claude-resources/default.nix`: optionally add per-source flat-dir derivations (or point straight at the input's tree if its layout matches), append a `mkCatalog "<name>" { … };` block, and add a `ln -sfn` line in the activation script.
3. Add a `<name>` entry in `Notes/claude/lazy/lazy.json` (description shown in `claude-kit lazy ls`).

### Per-project use

```
claude-kit lazy ls                          # browse all catalogs (with item counts)
claude-kit lazy ls ruflo                    # contents of one catalog
claude-kit lazy ls --type skills            # filter across catalogs
claude-kit lazy show <type> <name>          # description + rendered file
claude-kit lazy add  <type> <name>          # edit ./claude-kit.nix + sync (or symlink direct if no nix file)
claude-kit lazy add  <catalog>/<type>/<name>   # disambiguate
claude-kit lazy add  --imperative <type> <name>  # bypass nix-file edit; write ./.claude/ directly
claude-kit lazy rm   <type> <name>          # mirror of add; --imperative also accepted
claude-kit lazy project [--global]          # list project-scope (--global also lists catalog)
claude-kit lazy new <name>                  # scaffold new sub-catalog under Notes/claude/lazy/
claude-kit lazy refresh <name>              # regenerate <name>/catalog.json from contents
claude-kit lazy doctor                      # validate manifests
```

### Bundles — activate a stack in one shot

A **bundle** is a JSON manifest at `<catalog>/bundles/<name>.json` listing plugins/MCP/skills/agents/commands to enable together. The `ruflo` sub-catalog ships a `ruflo` bundle (8 ruflo plugins, generated from `claude-resources/build/ruflo-bundles.sh`). Add new bundles by hand-writing `<personal-catalog>/bundles/<name>.json` or, for a new upstream source, by adding a `<source>-bundles.sh` build script alongside the existing one.

```
claude-kit lazy bundle ls                   # list bundles (* marks applied to cwd)
claude-kit lazy bundle show <name>          # print bundle contents (jq+bat)
claude-kit lazy bundle add <name>           # in a den project: append every entry into claude-kit.nix + sync; otherwise direct merge into ./.claude/
claude-kit lazy bundle rm <name>            # reverse using ./.claude/.lazy-bundles.json state
claude-kit lazy bundle status               # what's applied to cwd
```

Apply state is tracked in `./.claude/.lazy-bundles.json` so `rm` reverses precisely what `add` wrote (regardless of whether the bundle JSON has changed since). Each entry carries a `mode: "declarative"\|"imperative"` field — declarative bundles were merged into `claude-kit.nix`, so `bundle rm` removes the same lines from the nix file and re-syncs; imperative bundles wrote symlinks + jq edits directly, so `rm` reverses those. When the state file becomes empty, it's auto-deleted.

**Ruflo workflow** — bundle activation is composed with `ruflo init`:

```
cd ~/projects/foo
ruflo init                                  # writes .mcp.json + .claude-flow/ + .swarm/
claude-kit lazy bundle add ruflo            # appends 8 plugins to claude-kit.nix:plugins (or, outside a den project, writes them straight into .claude/settings.local.json)
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

`claude.nix` registers two marketplaces via `programs.claude-code.settings.extraKnownMarketplaces`: `ruflo` (source `github:ruvnet/ruflo`) and `caveman` (source `github:JuliusBrussee/caveman`). Ruflo plugins stay opt-in per-project via `claude-kit lazy add plugin ruflo-core@ruflo`; caveman is enabled globally (see "Always-on plugins"). To pin a specific marketplace ref, add `ref = "<rev>"` to the source attrset.

### Always-on shortlist

What stays globally loaded (in `~/.claude/skills/`):

- The 1 local skill under `Notes/claude/skills/`: `memory-load` (universally useful — keep global). Wired via live `mkOutOfStoreSymlink`.
- `extraSkills` in `claude.nix` — `gstack` (umbrella) + `office-hours` + `plan-eng-review` from `inputs.gstack`; `grill-me` + `handoff` from `inputs.mattpocock-skills` (self-contained, no umbrella needed); `balanced` from `inputs.glebis-claude-skills` (self-contained).

What moved to **project-scoped** in `Notes/claude/lazy/personal/skills/` (each pairs with an optional MCP that's also project-opt-in):

| Skill | Paired MCP | Why project-scoped |
|---|---|---|
| `code-search` | `code-index` | Calls `mcp__code-index__*` tools — only works after per-repo Qdrant indexing. |
| `code-exploration` | `code-index` | Same dependency. |
| `excalidraw-sketches` | `excalidraw` | Calls `mcp__excalidraw__*` tools — only useful when actively producing scenes. |
| `mermaid-diagrams` | `mermaid` | Diagram authoring — niche per project. |
| `obsidian-vault` | `basic-memory` | Vault path is `~/killuanix/Notes`; only relevant when working with notes. |
| `obsidian-clipper` | — | Triages web clips in vault inbox; pull in when needed. |

Add to a project via `claude-kit.nix:skills = [ ... ];`. Resolves through the `personal` lazy catalog.

To add a frequently-used upstream skill to the always-on set, add it to `extraSkills` rather than enabling it per-project everywhere.

### Always-on plugins

`enabledPlugins."caveman@caveman" = true` in `claude.nix` enables the [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) plugin globally. It bundles a "caveman-speak" response-style skill (advertised ~75% token reduction), companion skills (`caveman-commit`, `caveman-review`, `caveman-help`, `caveman-stats`, `cavecrew`, `compress`), and Node-based `SessionStart` / `UserPromptSubmit` hooks that auto-activate the mode. Hooks need `node` on PATH — currently provided transitively by `nodejs_20` from `ruflo-cli.nix`/`claude-flow-cli.nix`. The upstream `caveman-shrink` MCP proxy is intentionally **not** registered: it's a stdio wrapper that compresses *another* MCP server's output, not a standalone server, so registering it bare (the way upstream's `install.sh` does) just produces a "missing upstream command" failure on every session start. Re-add it only if you want to wrap a specific chatty MCP — see `modules/common/mcp-servers.nix` for shape. To disable, flip the entry to `false` and `scripts/nix_switch`; the marketplace registration is cheap enough to leave in place.

**Stop hook — per-session statusline savings badge**: `local.extraHooks.Stop` (declared in `claude.nix`; aggregated into `programs.claude-code.settings.hooks` alongside claudio + claude-hooks contributions) writes a *per-session* `⛏ <Nk>` suffix into the overlay's `.caveman-statusline-suffix` after every assistant turn. Each concurrent claude session's badge therefore shows **only that session's saved tokens** — lifetime / 5h-block aggregation lives separately in the `caveman stats` shell wrapper (see entry below).

Implementation intentionally **bypasses the upstream `caveman-stats.js`**, which aggregates lifetime totals across every session's history snapshot — mirroring its output into every overlay would make every concurrent session's badge show the same number. Instead, the hook:

1. Reads the Stop hook stdin payload (Claude Code passes `{transcript_path, session_id, …}`) to get the path of *this session's* jsonl.
2. Reads the live mode from the overlay's `$CLAUDE_CONFIG_DIR/.caveman-active` (caveman-activate.js wrote it there at SessionStart). Empty / non-benchmarked mode → blank suffix and exit.
3. Streams the jsonl, sums `entry.message.usage.output_tokens` across all `assistant` entries belonging to that one session.
4. Computes savings as `round(out / (1 - ratio)) - out` (ratio = 0.65 for `full`, the only mode with benchmark data), humanises to `⛏ <N>k|M`, and writes the result to `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix` with a symlink check (matching `caveman-statusline.sh`'s defence against ANSI injection via the flag file).

No lifetime history file is maintained — the `caveman stats` CLI reads jsonls directly via `~/.claude/projects/**/*.jsonl` so it doesn't need a history snapshot. The hook's failure modes are all soft (`|| true`, swallowed errors, blank suffix on missing data) so a bad payload never breaks the session.

`overlayClaude` cooperates: it skips symlinking *and* pre-copying `.caveman-active` + `.caveman-statusline-suffix` (see "## /effort overlay wrapper") so each session's overlay starts fresh and isolated. Symlinking the suffix through would let every concurrent claude process's Stop hook follow the symlink and write through to one shared file (badges converge), and symlinking the active flag would block caveman-activate.js's `safeWriteFlag` entirely.

**`caveman` shell wrapper** at `scripts/caveman` is a dispatcher (`caveman <subcommand>`) front-end for caveman state in `~/.claude/`. Currently only `caveman stats` is implemented; it surfaces **token usage** for the current ~5 h Anthropic rate-limit block. Implementation: walk every `*.jsonl` under `~/.claude/projects/` modified within the last 5 h, parse each `entry.message.usage` whose `entry.timestamp` falls in the rolling 5 h window, bucket by model, and report turns + per-token-type counts (`input` / `output` / `cache_read` / `cache_create`). Block start is approximated as the oldest in-window entry's timestamp — independent of how long any single claude process has run, so a day-long session that straddled three rate-limit blocks only contributes the in-block portion. Multi-model aware (Opus + Sonnet usage in the same block are summed correctly).

**USD cost is intentionally hidden** — the user is on a flat-rate Claude plan, not raw API billing, so dollar figures are meaningless for their workflow. The Anthropic per-million-token price table + `pricesFor` / `tokenCost` / `formatUsd` helpers are retained in the script behind a `SHOW_COST = false` flag (block-commented). Flip the flag and uncomment the helpers + re-wire the `lines.push` / final `process.stdout.write` blocks to re-enable USD output; refresh rates from https://www.anthropic.com/pricing when doing so.

The caveman savings estimate (`mod.COMPRESSION[mode]` × per-model output) is appended as **token count only** when `mode = full`. Mode is resolved with a fallback search: real `~/.claude/.caveman-active`, then the most-recent `.caveman-active` under `$XDG_RUNTIME_DIR/claude-session.*/` — because caveman-activate.js writes the flag inside the per-PID overlay dir and the overlay is torn down at session exit, so a terminal-side `caveman stats` would otherwise always see `mode=off`. Lives in `scripts/` (already on PATH via the user's shell config), so future caveman state tools (e.g. `caveman history`, `caveman reset`) are added as subcommands here rather than as new top-level binaries.

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

### Dev-shell bootstrap

Orthogonal to the preset choice: `den new` can also seed a Nix dev shell from `the-nix-way/dev-templates` (pinned as `inputs.dev-templates`, exposed to the bash CLI as `$DEN_DEV_TEMPLATES_DIR`).

- `den new myproj --devshell python` — non-interactive; copies template into `files/`, hardlinks `flake.nix`/`flake.lock` (mandatory: nix flakes can't follow absolute symlinks out of their own tree), writes `.envrc` (`use flake`), appends `.direnv/` to `.denignore`.
- `den new myproj --no-devshell` — non-interactive skip (pre-feature behavior).
- `den new myproj` on TTY → prompts; non-TTY → skips silently.
- After bind+pull, runs `direnv allow` automatically on TTY (so `cd` into the bound dir loads the shell). Non-TTY prints a hint.

Bump the template set with `nix flake lock --update-input dev-templates`. Existing projects keep their pinned `flake.lock` (lives in `Notes/projects/<N>/files/`). `nix-direnv` itself is enabled globally in `modules/common/programs.nix`. See `den/CLAUDE.md` → `## Dev-shell bootstrap` for the helper-by-helper breakdown.

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
