{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  code-index-mcp = import ../../../../../packages/code-index-mcp/package.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
in {
  # Custom code-index MCP server (not in the mcp-servers-nix catalog).
  # Secrets come from sops-nix. `programs.claude-code.enable` + skills are
  # configured in ./claude.nix; skills themselves live alongside it under ./skills.
  #
  # `optional = true` keeps this out of the global mcpServers list so it
  # only loads in projects that opt in via `claude-kit.nix:mcp = [ "code-index" ]`
  # (and have run `code-index` indexing for the repo). claude.nix routes
  # `local.extraMcpServers` through the same global-filter + all-mcp-servers.json
  # catalog pipeline as the registry.
  local.extraMcpServers.code-index = {
    command = "${code-index-mcp}/bin/code-index-mcp";
    env = {
      # Point at the local Qdrant quadlet container from modules/containers/qdrant.nix.
      # No api-key needed — the local instance runs without auth.
      QDRANT_URL = "http://127.0.0.1:6333";
      NVIDIA_API_KEY_FILE = config.sops.secrets."nvidia_api_key".path;
    };
    optional = true;
  };
}
