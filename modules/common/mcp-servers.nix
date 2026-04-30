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

  libreoffice = {
    gitSource = {
      owner = "patrup";
      repo = "mcp-libre";
      rev = "edc5123dcd740049c54de9bc9abf8d69b2f1293f";
      hash = "sha256-J0oXBvn5Bejnn6p6cc4He6lfk+aFnuMSgxJBGhcS6EE=";
    };
    runtime = "uv-run";
    entrypoint = "src/main.py";
    # Upstream is unmaintained at this rev. Local fixes:
    #   - create_document(doc_type="calc") now produces a real empty file
    #     (previously wrote 0-byte via touch()).
    #   - New write_spreadsheet_data tool for populating .xlsx / .ods cells.
    patches = [./programs/dev/patches/mcp-libre-calc-and-write.patch];
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
  };

  # @peng-shawn/mermaid-mcp-server — renders Mermaid source to PNG/SVG via
  # puppeteer. The PUPPETEER_EXECUTABLE_PATH override lives in claude.nix
  # (needs pkgs.chromium at eval time). Companion live-editor container at
  # http://localhost:8898 (modules/containers/mermaid-live.nix).
  mermaid = {
    npxDirect.package = "@peng-shawn/mermaid-mcp-server";
    runtime = "npx-direct";
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
  };
}
