{
  pkgs,
  lib,
  ...
}: let
  kindlyRepoUrl = "https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server";

  # Lazy `uvx --from git+URL` invocation for the kindly-web-search MCP server.
  # uv handles resolution + venv build under $UV_CACHE_DIR. First call is slow
  # (30–60 s); subsequent calls hit cache. Bumping the URL (e.g. appending
  # `@<rev>`) invalidates the resolved entry.
  kindlyWrapper = pkgs.writeShellApplication {
    name = "mcp-kindly-web-search";
    runtimeInputs = [pkgs.uv];
    text = ''
      export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-kindly/uv-cache"
      mkdir -p "$UV_CACHE_DIR"
      exec uvx \
        --from ${lib.escapeShellArg "git+${kindlyRepoUrl}"} \
        kindly-web-search-mcp-server start-mcp-server "$@"
    '';
  };
in {
  # kindly-web-search — web search + page-content extraction MCP, backed by the
  # local SearXNG container (modules/containers/searxng.nix on :8888). Chromium
  # is required at runtime for the `page_content` headless-browser extraction.
  #
  # Lives outside modules/common/mcp-servers.nix because the chromium binary
  # path needs pkgs in scope. Registers via the `local.extraMcpServers`
  # side-channel declared in claude.nix — same pattern as code-index.nix.
  #
  # `optional = true` keeps it out of the global mcpServers list so it only
  # loads in projects that opt in via `claude-kit.nix:mcp = [ "kindly-web-search" ]`
  # (or `claude-kit lazy add mcp kindly-web-search` outside a den project).
  local.extraMcpServers.kindly-web-search = {
    command = lib.getExe kindlyWrapper;
    env = {
      # Use the local SearXNG as the search backend — no API key needed.
      SEARXNG_BASE_URL = "http://localhost:8888/";
      # Headless browser for full page-content extraction. Same chromium build
      # the mermaid MCP uses via PUPPETEER_EXECUTABLE_PATH.
      KINDLY_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      # Upstream README flags Windows-style timeout issues; keep the bump
      # everywhere since cold-cache uvx resolves can take a while.
      KINDLY_TOOL_TOTAL_TIMEOUT_SECONDS = "180";
    };
    optional = true;
  };
}
