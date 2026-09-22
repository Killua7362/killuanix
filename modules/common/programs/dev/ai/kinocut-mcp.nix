# Kinocut MCP server — KyaniteLabs/mcp-video (PyPI `kinocut`, formerly `mcp-video`).
#
# Typed FFmpeg tool surface for AI-agent video editing: 196 MCP tools /
# 167 CLI cmds — trim/crop/resize, **9:16 reframe**, overlays, subtitle burn,
# scene detection, thumbnails, concat/transitions, loudness. The clipping
# companion to `youtube-mcp.nix` (discover) + the `clipify` skill (moment
# selection + pan/caption): once Claude has picked in/out timestamps, kinocut
# renders the cuts through named tools instead of hand-rolled ffmpeg Bash.
#
# Apache-2.0, **fully local, no account / API key**. Only hard requirement is
# `ffmpeg` on PATH (the wrapper injects `pkgs.ffmpeg-full`). Launch is the
# upstream-documented `uvx --from kinocut kino` (bare `kino` = start the MCP
# server); `uvx` resolves + caches the wheel on first call under
# $XDG_CACHE_HOME/mcp-kinocut/uv-cache (youtube-trends-mcp / postgres-mcp idiom
# — no nix hash to maintain; bump `kinocutVersion` to upgrade).
#
# Optional Whisper transcribe/stem/upscale extras (`kinocut[transcribe]` …) are
# NOT installed — they pull ~1-2 GB of torch each, and transcription is already
# covered by the project's whisperX pipeline. Add an extra by switching the
# pin to `--from "kinocut[transcribe]==<ver>"` if you want kino's own STT tools.
#
# `optional = true` — NOT loaded globally. Opt in per-project via
#   claude-kit.nix:mcp = [ "kinocut" ];
{
  pkgs,
  lib,
  ...
}: let
  kinocutVersion = "1.15.1";

  kinocutWrapper = pkgs.writeShellApplication {
    name = "mcp-kinocut";
    runtimeInputs = [pkgs.uv pkgs.ffmpeg-full];
    text = ''
      export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-kinocut/uv-cache"
      exec uvx --from "kinocut==${kinocutVersion}" kino "$@"
    '';
  };
in {
  local.extraMcpServers.kinocut = {
    command = lib.getExe kinocutWrapper;
    optional = true;
  };
}
