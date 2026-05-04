# `gitnexus` CLI shim — light-weight wrapper over `npx gitnexus@<pinned>`.
#
# Same lazy-install pattern as ruflo-cli.nix / ccr.nix: no Nix-store npm
# closure, first invocation downloads under $XDG_CACHE_HOME/gitnexus/,
# subsequent invocations are instant.
#
# Cache root MUST stay aligned with the `gitnexus` MCP entry's
# `cacheNamespace = "gitnexus"` in modules/common/mcp-servers.nix — both shims
# share `~/.cache/gitnexus/{npm-cache,npm-prefix}` so Claude Code's MCP
# connect probe doesn't time out re-resolving the dep tree on cold start
# (same gotcha that drives the claude-flow ↔ ruflo-cli sharing).
#
# CLI surface (see `gitnexus --help` for full list):
#   gitnexus analyze [path]   → build per-repo index at <repo>/.gitnexus/
#   gitnexus list             → list indexed repos in ~/.gitnexus/registry.json
#   gitnexus status           → staleness for current repo
#   gitnexus clean [--all]    → drop indexes
#   gitnexus mcp              → MCP server (also exposed as the `gitnexus` MCP)
#   gitnexus serve            → HTTP UI on :4747 (run manually if wanted)
#   gitnexus wiki             → LLM-generated docs (needs OPENAI_API_KEY)
#
# Licence: PolyForm Noncommercial. Fine for personal/dev use; commercial use
# needs a separate licence from upstream.
{
  pkgs,
  lib,
  ...
}: let
  # Track upstream's main release; bump only when the CLI surface changes
  # in a way the registry entry / docs depend on. Kept aligned with the
  # `gitnexus` entry in modules/common/mcp-servers.nix by convention.
  gitnexusVersion = "latest";

  gitnexus = pkgs.writeShellApplication {
    name = "gitnexus";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/gitnexus/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/gitnexus/npm-prefix"
      # npm lstat()s {prefix}/lib and {prefix}/bin on startup — pre-create
      # them so `npx` doesn't ENOENT on first use.
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "gitnexus@${gitnexusVersion}" "$@"
    '';
  };
in {
  home.packages = [gitnexus];
}
