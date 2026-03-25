{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  code-index-mcp = import ../../../../packages/code-index-mcp/package.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
in {
  programs.claude-code.enable = true;

  programs.claude-code.mcpServers.code-index = {
    command = "${code-index-mcp}/bin/code-index-mcp";
    env = {
      QDRANT_URL_FILE = config.sops.secrets."qdrant_cluster_endpoint".path;
      QDRANT_API_KEY_FILE = config.sops.secrets."qdrant_api_key".path;
      NVIDIA_API_KEY_FILE = config.sops.secrets."nvidia_api_key".path;
    };
  };

  programs.claude-code.skillsDir = ./skills;
}
