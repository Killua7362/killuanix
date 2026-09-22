# fileshare MCP server — upload files to litterbox (catbox), get a share link.
#
# Single-file Python script with PEP 723 inline metadata (mcp<2 + httpx),
# launched via `uv run --quiet --script`; uv resolves the dep set on first
# call and caches under $UV_CACHE_DIR. Same idiom as freshrss-mcp/.
#
# Backend is litterbox.catbox.moe — anonymous, no auth, so (unlike
# freshrss/cosmos/postgres) there is NO sops secret to wire; the module is pure
# `pkgs`. Expiry is a FIXED bucket (1h/12h/24h/72h — no arbitrary TTL);
# default 1h. Files auto-delete at expiry; litterbox has NO delete
# or listing API, so `list_uploads` reads a local JSON ledger
# ($XDG_DATA_HOME/fileshare-mcp/uploads.json) of what this MCP uploaded.
#
# litterbox is immutable — no in-place edit. "Modify" = re-upload = a NEW url.
# Tools: upload_file, upload_content, list_uploads.
#
# Backend history: first tried 0x0.st (disabled uploads in 2026 over AI-bot
# spam → 503), transfer.sh ruled out (flaky public host, immutable). litterbox
# rides catbox infra — reliable. `mcp<2` pin is load-bearing: bare `mcp>=1.0`
# now resolves mcp 2.x, which renamed FastMCP→MCPServer (import crash →
# connection_closed in Claude Code). Same trap postgres-mcp.nix documents.
#
# Registers via `local.extraMcpServers.fileshare` (side-channel in claude.nix)
# with `optional = true` — does NOT load in every session. Opt in per-project
# via `claude-kit.nix:mcp = [ "fileshare" ];` or `claude-kit lazy add mcp
# fileshare`.
{
  pkgs,
  lib,
  ...
}: let
  serverSrc = pkgs.runCommand "fileshare-mcp-src" {} ''
    mkdir -p $out
    cp ${./server.py} $out/server.py
    chmod 0644 $out/server.py
  '';

  fileshareWrapper = pkgs.writeShellApplication {
    name = "mcp-fileshare";
    runtimeInputs = [pkgs.uv];
    text = ''
      export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-fileshare/uv-cache"
      mkdir -p "$UV_CACHE_DIR"
      exec uv run --quiet --script ${serverSrc}/server.py "$@"
    '';
  };
in {
  local.extraMcpServers.fileshare = {
    command = lib.getExe fileshareWrapper;
    env = {
      FILESHARE_API_URL = "https://litterbox.catbox.moe/resources/internals/api.php";
      FILESHARE_DEFAULT_EXPIRY = "1h";
    };
    optional = true;
  };
}
