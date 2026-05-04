# External Claude Code bundles — ruflo + wshobson/agents flattened into
# ~/.claude/{agents,commands,skills}/, plus an auto-generated catalog.json
# under Notes/claude/lazy/upstream/ that lists every flattened resource for
# per-project opt-in via `claude-kit lazy`.
#
# The bash bodies live as plain `.sh` files under ./build/ so a shell LSP
# can navigate them. Nix-injected store paths are passed via env vars on
# each runCommand invocation — see ./CLAUDE.md.
#
# Naming scheme (keeps Claude Code's flat standalone namespace collision-free):
#   ruflo:                 ruflo--<subpath-with-slashes-as-dashes>.md
#   wshobson/agents:       wshobson--<plugin>--<basename>.md
#   skills (directories):  ruflo--<name>/  and  wshobson--<plugin>--<name>/
#   anthropics-skills:     <upstream-name>/  (no prefix; upstream tree is flat)
#
# The three flat directories are built as pure derivations, then wired into
# Home Manager:
#   - agents + commands:  home.file with `recursive = true` (per-file symlinks,
#                         so user-created files in ~/.claude/{agents,commands}/
#                         aren't clobbered).
#   - skills:             fed into `programs.claude-code.skills` — the upstream
#                         claude-code-nix module handles ~/.claude/skills/.
#
# The upstream catalog (`Notes/claude/lazy/upstream/catalog.json`) is a single
# JSON file with `{name, path}` arrays per resource type. Paths are absolute
# nix-store paths so `claude-kit lazy add` can symlink them into a project
# without copying. Catalog includes anthropics-skills entries too.
#
# See ../CLAUDE.md → "External Claude Code bundles" for update workflow.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  ruflo = inputs.ruflo;
  wshobson = inputs.wshobson-agents;
  anthropicsSkills = inputs.anthropics-skills;

  # Flatten ruflo .claude/<kind>/**/*.md  and  wshobson plugins/*/<kind>/*.md
  # into a single directory of uniquely-named markdown files.
  mkFlatMarkdown = kind:
    pkgs.runCommand "claude-${kind}-flat" {
      KIND = kind;
      RUFLO = ruflo;
      WSHOBSON = wshobson;
    } (builtins.readFile ./build/flat-markdown.sh);

  # Build a directory containing one subdirectory per skill, each preserving
  # its SKILL.md + any referenced assets. We then enumerate subdirs for the
  # `skills` attrset.
  skillsDir = pkgs.runCommand "claude-skills-flat" {
    RUFLO = ruflo;
    WSHOBSON = wshobson;
  } (builtins.readFile ./build/flat-skills.sh);

  agentsDir = mkFlatMarkdown "agents";
  commandsDir = mkFlatMarkdown "commands";

  # Auto-generated catalog.json for the upstream sub-catalog. Lists every
  # resource flattened above plus anthropics-skills. Paths are absolute
  # nix-store paths; claude-kit lazy add symlinks straight to them.
  upstreamCatalog = pkgs.runCommand "claude-upstream-catalog" {
    nativeBuildInputs = [pkgs.jq];
    SKILLS_DIR = skillsDir;
    AGENTS_DIR = agentsDir;
    COMMANDS_DIR = commandsDir;
    ANTHROPICS_SKILLS = anthropicsSkills;
  } (builtins.readFile ./build/upstream-catalog.sh);

  # Auto-generated bundles for the upstream catalog. A bundle is a named
  # group of plugins / MCP servers / catalog items that `claude-kit lazy
  # bundle add <name>` activates per-project in one shot.
  upstreamBundles = pkgs.runCommand "claude-upstream-bundles" {
    nativeBuildInputs = [pkgs.jq];
  } (builtins.readFile ./build/upstream-bundles.sh);
in {
  # Upstream bundles are NO LONGER auto-installed into ~/.claude/. They live
  # in the lazy catalog (`Notes/claude/lazy/upstream/catalog.json`) and are
  # opted into per-project via `claude-kit lazy add`. The flat dirs are still
  # built (used by the catalog and the cache symlinks below); they're just
  # not wired into Claude Code's global startup.

  # Expose the built trees via HM-visible paths so claude-kit can walk them
  # without globbing the Nix store. Read-only symlinks; safe to inspect.
  home.file.".cache/claude-kit/sources/agents.link".source = agentsDir;
  home.file.".cache/claude-kit/sources/commands.link".source = commandsDir;
  home.file.".cache/claude-kit/sources/skills.link".source = skillsDir;
  home.file.".cache/claude-kit/sources/upstream-catalog.link".source = upstreamCatalog;
  home.file.".cache/claude-kit/sources/upstream-bundles.link".source = upstreamBundles;

  # Symlink the upstream catalog.json + bundles/ into the Notes vault so
  # they live next to user-curated catalogs and `claude-kit lazy ls` finds
  # them via the same auto-discovery mechanism. The Notes path is outside
  # HM's $HOME tree management (it's a real git repo), so we use an
  # activation script with `ln -sfn` rather than `home.file`.
  home.activation.lazyUpstreamCatalogSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _lazy_upstream="$HOME/killuanix/Notes/claude/lazy/upstream"
    mkdir -p "$_lazy_upstream"
    ln -sfn "${upstreamCatalog}/catalog.json" "$_lazy_upstream/catalog.json"
    ln -sfn "${upstreamBundles}" "$_lazy_upstream/bundles"
  '';
}
