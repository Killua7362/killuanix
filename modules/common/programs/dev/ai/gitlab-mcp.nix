# GitLab MCP server for the DAS self-hosted GitLab
# (gitlab-ext.digitalaviationservices.com).
#
# Lets Claude read merge requests, MR discussions/comments, diffs, issues and
# pipelines — paste an MR link and Claude resolves project + iid from it.
#
# Runtime: `@zereight/mcp-gitlab` (npm), resolved lazily via `npx --yes` on
# first call (apify/ruflo idiom — no nix hash; bump `version` to upgrade).
#
# Read-only, enforced twice:
#   1. GITLAB_READ_ONLY_MODE=true — server only registers read tools.
#   2. The token (`boeing/gitlab_token`) only has read_* scopes
#      (read_api, read_repository, read_user, read_virtual_registry), so
#      GitLab rejects any write server-side. Same token dev/git.nix hands
#      claude for `git pull`.
#
# Auth: GITLAB_PERSONAL_ACCESS_TOKEN_FILE points at the sops secret path, so
# the token never lands in the nix store, argv, or an env var.
#
# Network: the host is only reachable via the SOCKS5 proxy on 127.0.0.1:1080
# (same as git.nix's http.proxy). The server's undici client handles
# `socks*` HTTPS_PROXY URLs via socks-proxy-agent.
#
# `optional = true` — NOT loaded globally. Opt in per-project via
#   claude-kit.nix:mcp = [ "gitlab" ];
# (or `claude-kit lazy add mcp gitlab` outside a den project).
{
  pkgs,
  config,
  lib,
  ...
}: let
  version = "2.3.1";

  gitlabMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-gitlab";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      export GITLAB_API_URL="https://gitlab-ext.digitalaviationservices.com/api/v4"
      export GITLAB_PERSONAL_ACCESS_TOKEN_FILE="${config.sops.secrets."boeing/gitlab_token".path}"
      export GITLAB_READ_ONLY_MODE=true
      export HTTPS_PROXY="socks5h://127.0.0.1:1080"
      export HTTP_PROXY="$HTTPS_PROXY"
      exec npx --yes "@zereight/mcp-gitlab@${version}" "$@"
    '';
  };
in {
  local.extraMcpServers.gitlab = {
    command = lib.getExe gitlabMcpWrapper;
    optional = true;
  };
}
