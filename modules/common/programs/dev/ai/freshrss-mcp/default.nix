# FreshRSS MCP server — Greader API client exposed as MCP tools.
#
# Server is a single-file Python script with PEP 723 inline metadata; `uv run
# --script` resolves the (tiny) dep set (mcp + httpx) on first call and caches
# under $UV_CACHE_DIR. Tools: list_unread, list_starred, search, list_feeds,
# items_from_feed, list_categories, mark_read, star.
#
# Lives outside modules/common/mcp-servers.nix because the env wires a
# sops-rendered secret path (no `pkgs`/config in scope there). Registers via
# `local.extraMcpServers.freshrss` — same side-channel as code-index.nix /
# kindly-web-search.nix.
#
# `optional = true` so it does NOT load in every Claude Code session — the
# only place it activates is the `claude-news` launcher (claude-launchers.nix),
# which lists `mcp = [ "freshrss" ... ]` and resolves the stanza from the
# claude-kit catalog at launch time. Other projects can opt in via
# `claude-kit lazy add mcp freshrss` if desired.
#
# Auth uses the FreshRSS API password (NOT the web-login password — the
# Greader endpoint has its own credential), read from sops at
# `freshrss_admin_api_password`. The same key exists in
# modules/common/sops-system.nix (the freshrss container reads it as env);
# duplicating it under HM sops is the cleanest way to give the user-space
# MCP process read access without poking holes in the system secret's mode.
{
  pkgs,
  config,
  lib,
  ...
}: let
  serverSrc = pkgs.runCommand "freshrss-mcp-src" {} ''
    mkdir -p $out
    cp ${./server.py} $out/server.py
    chmod 0644 $out/server.py
  '';

  freshrssWrapper = pkgs.writeShellApplication {
    name = "mcp-freshrss";
    runtimeInputs = [pkgs.uv];
    text = ''
      export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-freshrss/uv-cache"
      mkdir -p "$UV_CACHE_DIR"
      exec uv run --quiet --script ${serverSrc}/server.py "$@"
    '';
  };
in {
  local.extraMcpServers.freshrss = {
    command = lib.getExe freshrssWrapper;
    env = {
      FRESHRSS_BASE_URL = "http://localhost:8083";
      FRESHRSS_USER = "killua";
      FRESHRSS_API_PASSWORD_FILE = config.sops.secrets.freshrss_admin_api_password.path;
    };
    optional = true;
  };
}
