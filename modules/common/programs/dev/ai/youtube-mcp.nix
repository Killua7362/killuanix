# YouTube MCP server — wynandw87/claude-code-youtube-mcp.
#
# Built for Claude Code. Tools for a YouTube clipper's whole loop: `trending`
# (find viral source videos by region), most-replayed **heatmap** (pinpoint the
# single most-rewatched segment = the exact clip to cut), transcripts, chapters,
# search, engagement analytics, comments, SponsorBlock.
#
# NOT on npm — upstream ships a TS project you build (`npm install` auto-builds
# dist/index.js). Lazy-built into $XDG_CACHE_HOME on first call (cc-hooks-ts /
# ruflo / cosmos-mcp idiom — no nix hash to maintain); floating HEAD, pin by
# editing `ref`.
#
# Auth: YOUTUBE_API_KEY = a YouTube Data API v3 key (Google Cloud Console →
# enable "YouTube Data API v3" → API key; free, no card, 10k units/day). Rides a
# sops-rendered env file so the key never lands in the nix store / argv (mirrors
# apify-mcp.nix / cosmos-mcp.nix). 5 of the 15 tools (transcripts, SponsorBlock,
# heatmaps, URL parse) work even with an empty key; the other 10 (trending,
# search, analytics, comments…) need it. Add `youtube/data_api_key` to
# secrets/personal.yaml before switching (an empty value is allowed if you only
# want the 5 keyless tools).
#
# `optional = true` — NOT loaded globally. Opt in per-project via
#   claude-kit.nix:mcp = [ "youtube" ];
{
  pkgs,
  config,
  lib,
  ...
}: let
  ref = "main";

  youtubeMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-youtube";
    runtimeInputs = [pkgs.nodejs pkgs.git];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-youtube/${ref}"
      if [ ! -e "$cache/dist/index.js" ]; then
        rm -rf "$cache"
        git clone --depth 1 --branch "${ref}" https://github.com/wynandw87/claude-code-youtube-mcp "$cache"
        # npm install auto-builds dist/index.js (upstream prepare script).
        (cd "$cache" && npm install --no-audit --no-fund)
      fi
      # YOUTUBE_API_KEY from the sops-rendered env file (kept out of nix store).
      set -a
      # shellcheck disable=SC1091
      . "${config.sops.templates."youtube-mcp.env".path}"
      set +a
      exec node "$cache/dist/index.js" "$@"
    '';
  };
in {
  sops.templates."youtube-mcp.env".content = ''
    YOUTUBE_API_KEY=${config.sops.placeholder."youtube/data_api_key"}
  '';

  local.extraMcpServers.youtube = {
    command = lib.getExe youtubeMcpWrapper;
    optional = true;
  };
}
