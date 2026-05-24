# Canonical MCP server registry — single source of truth.
#
# Consumed by:
#   - modules/common/programs/dev/claude.nix    (Home Manager → Claude Code)
#   - modules/containers/litellm.nix            (NixOS → LiteLLM container image)
#
# Three entry shapes are supported:
#
# 1) Catalog entry (natsukium/mcp-servers-nix):
#    mcpServerNix  - package name exposed by natsukium/mcp-servers-nix
#                    (used by Claude Code to invoke the Nix-built binary)
#    runtime       - "npx" | "uvx" — pre-warm lane inside the LiteLLM image
#    package       - npm or PyPI package name (for the runtime above)
#    args          - default CLI args (optional)
#    env           - environment variables (optional)
#
# 2) Git-sourced entry (for servers with no PyPI/npm publish):
#    gitSource     - { owner; repo; rev; hash; }  → passed to fetchFromGitHub
#    runtime       - "uv-run" — uv manages a pyproject-based venv at first run
#                    (extend the dispatcher in claude.nix to add pipx/npm variants)
#    entrypoint    - path inside the repo (e.g. "src/main.py")
#    env           - environment variables (optional)
#
#    Git-sourced entries are not pre-warmed by the LiteLLM image (their runtime
#    value doesn't match the "npx"/"uvx" filters there).
#
#    To bump: `git ls-remote <url> HEAD` for the new rev, then
#    `nix-prefetch-github <owner> <repo> --rev <rev>` for the hash.
#
# 3) npx-direct entry (for Node.js servers not yet in the natsukium catalog):
#    npxDirect.package - npm package name, resolved lazily on first call via
#                        `npx --yes <package>` (mirrors ruflo-cli.nix). No
#                        Nix-level version pin — npm caches under $XDG_CACHE_HOME.
#    runtime           - "npx-direct" (informational; also excludes these from
#                        the LiteLLM pre-warm list).
#    args              - default CLI args (optional). Forwarded by Claude Code
#                        to the wrapper script, which passes them through "$@"
#                        to `npx --yes <package>`. Use this when the npm binary
#                        needs a subcommand (e.g. `ruflo mcp start`) rather
#                        than starting an MCP server on bare invocation.
#    env               - environment variables (optional). Nix-path-dependent
#                        values (e.g. chromium path for puppeteer) must be
#                        declared in the `mcpEnvOverrides` attrset in
#                        modules/common/programs/dev/claude.nix, not here, since
#                        this file has no `pkgs` in scope.
#
# 4) uvx-direct entry (for Python/PyPI servers not yet in the natsukium catalog):
#    uvxDirect.package - PyPI package name, resolved lazily on first call via
#                        `uvx <package>`. uv caches resolved envs under
#                        $UV_CACHE_DIR. Mirrors npx-direct but for Python.
#    runtime           - "uvx-direct" (informational; excluded from LiteLLM
#                        pre-warm list).
#    args              - default CLI args (optional). Forwarded as "$@" to
#                        `uvx <package>`. Use when the package's MCP entrypoint
#                        needs a subcommand (e.g. `basic-memory mcp`).
#    env               - environment variables (optional).
#
# Per-entry flags applicable to all shapes:
#
#    optional = true  — exclude from Claude Code's global mcpServers wiring
#                       (programs.claude-code.mcpServers in claude.nix). Resolved
#                       stanza still appears in $XDG_DATA_HOME/claude-kit/
#                       all-mcp-servers.json so `claude-kit project sync` can
#                       mirror it into a project's local ./.mcp.json on demand.
#                       Use for servers that need per-project setup (e.g.
#                       claude-flow after `ruflo init`, gitnexus after
#                       `gitnexus analyze`) and shouldn't load everywhere.
{
  filesystem = {
    mcpServerNix = "mcp-server-filesystem";
    runtime = "npx";
    package = "@modelcontextprotocol/server-filesystem";
    args = ["/home/killua"];
  };

  fetch = {
    mcpServerNix = "mcp-server-fetch";
    runtime = "uvx";
    package = "mcp-server-fetch";
  };

  memory = {
    mcpServerNix = "mcp-server-memory";
    runtime = "npx";
    package = "@modelcontextprotocol/server-memory";
    env.MEMORY_FILE_PATH = "/home/killua/.local/share/claude/memory.json";
  };

  sequential-thinking = {
    mcpServerNix = "mcp-server-sequential-thinking";
    runtime = "npx";
    package = "@modelcontextprotocol/server-sequential-thinking";
  };

  # jwingnut/mcp-libre — UNO-aware LibreOffice MCP. Two pieces:
  #   1. An .oxt extension installed into LibreOffice itself (HTTP server on
  #      :8765, started via Tools > MCP Server > Start MCP Server). Built and
  #      installed manually — not packaged by this entry. Source lives under
  #      `plugin/` in the upstream repo; build with `plugin/build.sh`, install
  #      with `unopkg add ./build/libreoffice-mcp-extension-*.oxt`.
  #   2. The stdio FastMCP bridge at `libreoffice_mcp_server.py` (repo root) —
  #      what this entry wires up. Talks to the extension over localhost HTTP
  #      and exposes tools to Claude Code via stdio.
  #
  # Operates on the *live* document model via UNO (multi-doc, real-time), not
  # on file paths. LibreOffice must be running with the extension's MCP server
  # started before claude can query.
  #
  # Previous wiring was patrup/mcp-libre (file-based, unmaintained, needed a
  # local patch). Dropped along with patches/mcp-libre-calc-and-write.patch.
  libreoffice = {
    gitSource = {
      owner = "jwingnut";
      repo = "mcp-libre";
      rev = "69ef5e55bf0258af03f6aed6667c81fc133643c3";
      hash = "sha256-8W7cOZ6YpyHg2U6uJ/wAnqVG7PAEo8hKxKmju55akWk=";
    };
    runtime = "uv-run";
    entrypoint = "libreoffice_mcp_server.py";
    # Upstream's `pyproject.toml` forgets to declare `fastmcp` — the bridge
    # script imports it but uv resolves only `mcp[cli]` / `httpx` / `pydantic`,
    # so the server fails to start with `ImportError: No module named 'fastmcp'`.
    patches = [./programs/dev/ai/patches/mcp-libre-add-fastmcp-dep.patch];
    # Per-project — needs LibreOffice running + .oxt extension installed +
    # in-app MCP server started. Opt in via
    # `claude-kit.nix:mcp = [ "libreoffice" ];`.
    optional = true;
  };

  # yctimlin/mcp_excalidraw — MCP tools for creating and editing .excalidraw
  # JSON scenes, plus an optional WebSocket canvas server for live sync.
  # Browse diagrams at http://localhost:8899 (container defined in
  # modules/containers/excalidraw.nix).
  excalidraw = {
    npxDirect.package = "mcp-excalidraw-server";
    runtime = "npx-direct";
    env = {
      # Distinct port so the MCP's embedded canvas server doesn't collide
      # with anything else binding :3000 (common dev-server default).
      PORT = "3031";
      EXPRESS_SERVER_URL = "http://localhost:3031";
    };
    # Per-project — binds :3031 and writes WebSocket canvas server state.
    # Only useful when actively producing .excalidraw scenes. Opt in via
    # `claude-kit.nix:mcp = [ "excalidraw" ];`.
    optional = true;
  };

  # @peng-shawn/mermaid-mcp-server — renders Mermaid source to PNG/SVG via
  # puppeteer. The PUPPETEER_EXECUTABLE_PATH override lives in claude.nix
  # (needs pkgs.chromium at eval time). Companion live-editor container at
  # http://localhost:8898 (modules/containers/mermaid-live.nix). Marked
  # `optional` — diagram authoring is niche per project, opt in via
  # `claude-kit.nix:mcp = [ "mermaid" ];` or a launcher's `mcp` list.
  mermaid = {
    npxDirect.package = "@peng-shawn/mermaid-mcp-server";
    runtime = "npx-direct";
    optional = true;
  };

  # basicmachines-co/basic-memory — markdown-backed knowledge graph MCP.
  # Pointed at the `Notes/claude/memory/` subtree so memory writes go directly
  # into the user's Obsidian vault (committed via `Obsidian Git: Create backup`).
  # Tools: write_note, read_note, edit_note (find_replace / append /
  # replace_section), search_notes, build_context, list_directory.
  #
  # IMPORTANT: prefer `append` / `replace_section` over `find_replace` against
  # the YAML frontmatter block — find_replace can mangle frontmatter on
  # surgical edits. The author guide at Notes/claude/memory/README.md codifies
  # this rule.
  #
  # Env vars: BASIC_MEMORY_HOME points at the live vault subdir. The
  # `--project` flag plus `mcp` subcommand starts the MCP server scoped to
  # that project. If basic-memory's CLI surface drifts, adjust args here.
  basic-memory = {
    uvxDirect.package = "basic-memory";
    runtime = "uvx-direct";
    args = ["mcp"];
    env = {
      BASIC_MEMORY_HOME = "/home/killua/killuanix/Notes/claude/memory";
      BASIC_MEMORY_PROJECT = "killuanix";
    };
  };

  # ruvnet/ruflo (a.k.a. "claude-flow") — multi-agent orchestration platform.
  # The npm `ruflo` binary doesn't start an MCP server on bare invocation; it
  # needs the `mcp start` subcommand. The MCP server name MUST be `claude-flow`
  # because the bundled `ruflo--*` skills (installed by claude-resources.nix)
  # call `mcp__claude-flow__*` tools — that prefix is hardcoded upstream.
  #
  # `cacheNamespace = "ruflo"` and `package = "ruflo@latest"` match
  # ruflo-cli.nix exactly, so the npx install populated by the standalone CLI
  # is reused here. Without this, Claude Code's MCP connect probe times out
  # on cold start while a separate cache resolves the entire ruflo dep tree.
  claude-flow = {
    npxDirect = {
      package = "ruflo@latest";
      cacheNamespace = "ruflo";
    };
    runtime = "npx-direct";
    args = ["mcp" "start"];
    # Per-project — claude-flow needs `ruflo init` to scaffold .mcp.json /
    # .claude-flow/ / .swarm/ in the project root before it does anything
    # useful. Opt in via `claude-kit.nix:mcp = [ "claude-flow" ];`.
    optional = true;
  };

  # abhigyanpatwari/GitNexus — Tree-sitter-backed code knowledge graph.
  # Complements `code-index` (registered separately in
  # programs/dev/ai/code-index.nix): code-index does semantic vector search
  # over Qdrant, GitNexus does relational queries (impact analysis, call
  # graphs, process tracing) over an embedded LadybugDB graph.
  #
  # MCP server runs over stdio with `gitnexus mcp`. The graph itself must be
  # built first per-repo with `gitnexus analyze` from the repo root; the
  # global registry of indexed repos lives at `~/.gitnexus/` and per-project
  # data at `<repo>/.gitnexus/` (gitignored via the global ignore file in
  # programs/dev/git.nix). No API key required for the core 16 MCP tools —
  # the optional `wiki` subcommand wants OpenAI/Anthropic creds but that's
  # not what we expose here.
  #
  # `cacheNamespace = "gitnexus"` matches the standalone CLI shim in
  # programs/dev/ai/gitnexus-cli.nix (same `~/.cache/gitnexus/` root) so the
  # MCP probe reuses the install populated by `gitnexus analyze` instead of
  # re-resolving the dep tree on Claude Code's cold start. Same pattern as
  # claude-flow ↔ ruflo above.
  gitnexus = {
    npxDirect = {
      package = "gitnexus@latest";
      cacheNamespace = "gitnexus";
    };
    runtime = "npx-direct";
    args = ["mcp"];
    # Per-project — gitnexus requires `gitnexus analyze` to build the
    # per-repo knowledge graph at <repo>/.gitnexus/ first. Opt in via
    # `claude-kit.nix:mcp = [ "gitnexus" ];`.
    optional = true;
  };
}
