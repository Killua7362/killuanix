# External Claude Code resource bundles — one lazy sub-catalog per upstream
# source under Notes/claude/lazy/<source>/, opted into per-project via
# `claude-kit lazy`. Sources currently wired: ruflo, wshobson/agents,
# anthropics/skills. Adding a new source = drop in a new `mkCatalog` block
# below + a symlink line in the activation script.
#
# The bash bodies live as plain `.sh` files under ./build/ so a shell LSP can
# navigate them. Nix-injected store paths are passed via env vars on each
# runCommand invocation — see ./CLAUDE.md.
#
# Naming inside each catalog (collision-free per source):
#   ruflo:               <subpath-with-slashes-as-dashes>
#   wshobson/agents:     <plugin>--<basename>
#   skills (directories):  ruflo: <name>;  wshobson: <plugin>--<name>
#   anthropics-skills:   <upstream-name>  (upstream tree is already flat)
#
# Bundles live next to the catalog they belong to. Only ruflo currently ships
# one (the 8-plugin stack); it lands at Notes/claude/lazy/ruflo/bundles/ruflo.json.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  ruflo = inputs.ruflo;
  wshobson = inputs.wshobson-agents;
  anthropicsSkills = inputs.anthropics-skills;
  gstack = inputs.gstack;
  glebisClaudeSkills = inputs.glebis-claude-skills;

  # Flat-markdown builders (one derivation per source × kind). Names inside
  # each derivation's $out are catalog-scoped — no outer prefix.
  mkFlatMarkdown = source: kind: srcAttr:
    pkgs.runCommand "claude-${source}-${kind}-flat" ({KIND = kind;} // srcAttr)
    (builtins.readFile (./build + "/flat-${source}-markdown.sh"));

  rufloAgents = mkFlatMarkdown "ruflo" "agents" {RUFLO = ruflo;};
  rufloCommands = mkFlatMarkdown "ruflo" "commands" {RUFLO = ruflo;};
  wshobsonAgents = mkFlatMarkdown "wshobson" "agents" {WSHOBSON = wshobson;};
  wshobsonCommands = mkFlatMarkdown "wshobson" "commands" {WSHOBSON = wshobson;};

  rufloSkills =
    pkgs.runCommand "claude-ruflo-skills-flat" {RUFLO = ruflo;}
    (builtins.readFile ./build/flat-ruflo-skills.sh);
  wshobsonSkills =
    pkgs.runCommand "claude-wshobson-skills-flat" {WSHOBSON = wshobson;}
    (builtins.readFile ./build/flat-wshobson-skills.sh);

  # Per-source catalog.json. Any of the three resource dirs may be omitted —
  # the missing kind surfaces as an empty array. Paths in the emitted JSON are
  # absolute nix-store paths so `claude-kit lazy add` symlinks straight to them.
  mkCatalog = catName: {
    skillsDir ? "",
    agentsDir ? "",
    commandsDir ? "",
  }:
    pkgs.runCommand "claude-${catName}-catalog" {
      nativeBuildInputs = [pkgs.jq];
      NAME = catName;
      SKILLS_DIR = skillsDir;
      AGENTS_DIR = agentsDir;
      COMMANDS_DIR = commandsDir;
    } (builtins.readFile ./build/catalog.sh);

  rufloCatalog = mkCatalog "ruflo" {
    skillsDir = rufloSkills;
    agentsDir = rufloAgents;
    commandsDir = rufloCommands;
  };
  wshobsonCatalog = mkCatalog "wshobson" {
    skillsDir = wshobsonSkills;
    agentsDir = wshobsonAgents;
    commandsDir = wshobsonCommands;
  };
  anthropicsSkillsCatalog = mkCatalog "anthropics-skills" {
    skillsDir = "${anthropicsSkills}/skills";
  };

  # gstack is upstream-shaped as one monolithic tree (root SKILL.md + 45
  # sub-skill dirs alongside bin/lib/scripts/docs that the sub-skills
  # reference via `~/.claude/skills/gstack/bin/...`). Wrap the whole input
  # under skills/gstack/ so a single `lazy add skill gstack` lands the
  # entire tree intact and the internal path refs resolve.
  gstackSkills = pkgs.runCommand "claude-gstack-skills-flat" {GSTACK = gstack;} ''
    mkdir -p "$out/gstack"
    cp -aL "$GSTACK"/. "$out/gstack/"
  '';
  gstackCatalog = mkCatalog "gstack" {
    skillsDir = gstackSkills;
  };

  # glebis/claude-skills is upstream-shaped as 60+ flat skill dirs at repo
  # root (plus `.claude-plugin/marketplace.json` + `BUNDLES.md` + a few
  # other top-level files). catalog.sh's glob skips dotfiles, so the
  # store path can be pointed at directly — but we copy into a clean
  # `$out/` first so the few non-skill top-level files (README.md,
  # BUNDLES.md, secrets.enc.yaml, .gitignore) don't leak into the
  # skills list once the catalog walks `*/`.
  glebisClaudeSkillsTree = pkgs.runCommand "claude-glebis-skills-flat" {GLEBIS = glebisClaudeSkills;} ''
    mkdir -p "$out"
    for sub in "$GLEBIS"/*/; do
      [ -d "$sub" ] || continue
      name=$(basename "$sub")
      # Skip the marketplace manifest dir; everything else is a skill.
      case "$name" in
        .claude-plugin) continue ;;
      esac
      cp -aL "$sub" "$out/$name"
    done
  '';
  glebisClaudeSkillsCatalog = mkCatalog "glebis-claude-skills" {
    skillsDir = glebisClaudeSkillsTree;
  };

  # Bundles live under their owning catalog. Only ruflo ships one today.
  rufloBundles =
    pkgs.runCommand "claude-ruflo-bundles" {
      nativeBuildInputs = [pkgs.jq];
    }
    (builtins.readFile ./build/ruflo-bundles.sh);
in {
  # Upstream resources are NOT auto-installed into ~/.claude/. They live in
  # the lazy catalogs and are opted into per-project via `claude-kit lazy`.

  # Expose every built tree via HM-visible cache paths so claude-kit can walk
  # them without globbing the Nix store. Read-only symlinks; safe to inspect.
  home.file.".cache/claude-kit/sources/ruflo-agents.link".source = rufloAgents;
  home.file.".cache/claude-kit/sources/ruflo-commands.link".source = rufloCommands;
  home.file.".cache/claude-kit/sources/ruflo-skills.link".source = rufloSkills;
  home.file.".cache/claude-kit/sources/wshobson-agents.link".source = wshobsonAgents;
  home.file.".cache/claude-kit/sources/wshobson-commands.link".source = wshobsonCommands;
  home.file.".cache/claude-kit/sources/wshobson-skills.link".source = wshobsonSkills;
  home.file.".cache/claude-kit/sources/ruflo-catalog.link".source = rufloCatalog;
  home.file.".cache/claude-kit/sources/wshobson-catalog.link".source = wshobsonCatalog;
  home.file.".cache/claude-kit/sources/anthropics-skills-catalog.link".source = anthropicsSkillsCatalog;
  home.file.".cache/claude-kit/sources/gstack-skills.link".source = gstackSkills;
  home.file.".cache/claude-kit/sources/gstack-catalog.link".source = gstackCatalog;
  home.file.".cache/claude-kit/sources/glebis-claude-skills.link".source = glebisClaudeSkillsTree;
  home.file.".cache/claude-kit/sources/glebis-claude-skills-catalog.link".source = glebisClaudeSkillsCatalog;
  home.file.".cache/claude-kit/sources/ruflo-bundles.link".source = rufloBundles;

  # Symlink each per-source catalog into the Notes vault so `claude-kit lazy
  # ls` auto-discovers them. Activation script also nukes the legacy
  # `upstream/` directory if a previous generation left it behind.
  home.activation.lazyUpstreamCatalogSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _lazy="$HOME/killuanix/Notes/claude/lazy"

    # Legacy single `upstream/` catalog — remove if present.
    if [ -e "$_lazy/upstream" ] || [ -L "$_lazy/upstream" ]; then
      rm -rf "$_lazy/upstream"
    fi

    # Previous hand-cloned gstack catalog at $_lazy/gstack/ — replace with
    # the nix-managed symlink layout.
    if [ -e "$_lazy/gstack" ] && [ ! -L "$_lazy/gstack" ]; then
      rm -rf "$_lazy/gstack"
    fi

    mkdir -p "$_lazy/ruflo" "$_lazy/wshobson" "$_lazy/anthropics-skills" "$_lazy/gstack" "$_lazy/glebis-claude-skills"

    ln -sfn "${rufloCatalog}/catalog.json"                 "$_lazy/ruflo/catalog.json"
    ln -sfn "${rufloBundles}"                              "$_lazy/ruflo/bundles"
    ln -sfn "${wshobsonCatalog}/catalog.json"              "$_lazy/wshobson/catalog.json"
    ln -sfn "${anthropicsSkillsCatalog}/catalog.json"      "$_lazy/anthropics-skills/catalog.json"
    ln -sfn "${gstackCatalog}/catalog.json"                "$_lazy/gstack/catalog.json"
    ln -sfn "${glebisClaudeSkillsCatalog}/catalog.json"    "$_lazy/glebis-claude-skills/catalog.json"
  '';
}
