# `ruflo` CLI shim — light-weight wrapper over `npx ruflo@<pinned>`.
#
# A full buildNpmPackage would pull ruflo's entire closure at eval time. We
# instead expose a thin shell wrapper that lazy-installs ruflo on first run
# under $XDG_CACHE_HOME/ruflo/ using the system `nodejs_20` (already in
# devPackages). Subsequent invocations are instant — no Nix-store bloat, no
# build-time npm evaluation.
#
# The pinned version below is kept in sync (by convention) with the `ruflo`
# flake input in flake.nix. Bumping one without the other only affects which
# on-disk markdown/CLI the user sees — not correctness — but keep them
# aligned to avoid drift.
{
  pkgs,
  lib,
  ...
}: let
  # NOTE: keep aligned with flake.nix `inputs.ruflo.url` rev → upstream
  # package.json version at that rev. Currently tracks the `main` release.
  rufloVersion = "latest";

  ruflo = pkgs.writeShellApplication {
    name = "ruflo";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ruflo/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/ruflo/npm-prefix"
      # npm lstat()s {prefix}/lib and {prefix}/bin on startup — pre-create
      # them so `npx` doesn't ENOENT on first use.
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "ruflo@${rufloVersion}" "$@"
    '';
  };
in {
  home.packages = [ruflo];
}
