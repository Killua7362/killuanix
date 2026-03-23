# Builds claude-monitor from PyPI using uv2nix.
# Expects: { pkgs, lib, uv2nix, pyproject-nix, pyproject-build-systems }
{ pkgs
, lib
, uv2nix
, pyproject-nix
, pyproject-build-systems
,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  python = pkgs.python3;

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
      ]);
in
pythonSet.mkVirtualEnv "claude-monitor-env" workspace.deps.default
