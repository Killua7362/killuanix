# Builds the `claude-kit-plan` venv from local source via uv2nix.
# Mirrors packages/jupyter-env-mcp/package.nix.
{
  pkgs,
  lib,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  python = pkgs.python312;

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {inherit python;}).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
    ]);
in
  pythonSet.mkVirtualEnv "claude-kit-plan-env" workspace.deps.default
