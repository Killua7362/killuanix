# YouTube Trends MCP server — trendsmcp.ai (source = youtube).
#
# Live YouTube search-interest / rising-topic trends — weekly + daily series,
# growth %, live YouTube trending searches. Catch a topic before it saturates
# and clip into it early. Complements youtube-mcp.nix (which finds the actual
# viral videos); this is the trend/keyword signal.
#
# IMPORTANT: the PyPI `youtube-trends-mcp` package is a **client SDK** (wraps
# `trendsmcp`), NOT a runnable stdio server — no __main__, no console script.
# The real MCP is trendsmcp.ai's **remote hosted** endpoint
# (https://api.trendsmcp.ai/mcp, `Authorization: Bearer`). We bridge that remote
# HTTP MCP to stdio with `mcp-remote` (lazy `npx`) so (a) Claude Code speaks its
# usual stdio, and (b) the token stays in a sops-rendered env file — mcp-remote
# expands `${TRENDSMCP_API_KEY}` in the header from the process env, so the
# secret never lands in the nix store, in this file's argv, or in ps output.
#
# Auth: TRENDSMCP_API_KEY — free key at https://trendsmcp.ai/account (100
# req/mo, no card, no per-platform keys). Add `trends/api_key` to
# secrets/personal.yaml before switching.
#
# `optional = true` — NOT loaded globally. Opt in per-project via
#   claude-kit.nix:mcp = [ "youtube-trends" ];
{
  pkgs,
  config,
  lib,
  ...
}: let
  endpoint = "https://api.trendsmcp.ai/mcp";

  trendsMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-youtube-trends";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      # TRENDSMCP_API_KEY from the sops-rendered env file (kept out of nix store).
      set -a
      # shellcheck disable=SC1091
      . "${config.sops.templates."youtube-trends-mcp.env".path}"
      set +a
      # mcp-remote bridges the remote HTTP MCP to stdio. The header is
      # SINGLE-quoted so bash does NOT expand it — mcp-remote itself substitutes
      # ''${TRENDSMCP_API_KEY} from the environment, keeping the token out of
      # argv/ps. No space after the colon (mcp-remote's header parser splits on
      # the first ':' and mishandles a leading space in the value).
      # SC2016: the single quotes are intentional — mcp-remote (not bash) does
      # the ''${TRENDSMCP_API_KEY} substitution, keeping the token out of argv.
      # shellcheck disable=SC2016
      exec npx --yes mcp-remote "${endpoint}" \
        --header 'Authorization:Bearer ''${TRENDSMCP_API_KEY}' "$@"
    '';
  };
in {
  sops.templates."youtube-trends-mcp.env".content = ''
    TRENDSMCP_API_KEY=${config.sops.placeholder."trends/api_key"}
  '';

  local.extraMcpServers.youtube-trends = {
    command = lib.getExe trendsMcpWrapper;
    optional = true;
  };
}
