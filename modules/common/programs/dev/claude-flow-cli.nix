# `claude-flow` CLI shim — light-weight wrapper over
# `npx @claude-flow/cli@<pinned>`.
#
# `claude-flow` is the runtime CLI invoked by `ruflo init`'s post-init
# guidance (`claude-flow daemon start`, `claude-flow memory init`,
# `claude-flow swarm init`, `claude-flow init --start-all`) and by the
# generated `.mcp.json` (`npx -y @claude-flow/cli@latest mcp start`).
# It is a separate npm package from `ruflo` itself but is published by
# the same project and version-bumps in lockstep on the upstream side.
#
# Same pattern as ./ruflo-cli.nix — no buildNpmPackage, no closure bloat.
# First run lazy-installs under $XDG_CACHE_HOME/claude-flow/; subsequent
# runs are instant.
{
  pkgs,
  lib,
  ...
}: let
  # NOTE: keep aligned with `rufloVersion` in ./ruflo-cli.nix and the
  # `inputs.ruflo.url` rev in flake.nix. Tracks the `main` release.
  claudeFlowVersion = "latest";

  claude-flow = pkgs.writeShellApplication {
    name = "claude-flow";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-flow/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-flow/npm-prefix"
      # npm lstat()s {prefix}/lib and {prefix}/bin on startup — pre-create
      # them so `npx` doesn't ENOENT on first use.
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "@claude-flow/cli@${claudeFlowVersion}" "$@"
    '';
  };
in {
  home.packages = [claude-flow];
}
