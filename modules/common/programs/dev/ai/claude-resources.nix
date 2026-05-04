# External Claude Code bundles — ruflo + wshobson/agents flattened into
# ~/.claude/{agents,commands,skills}/, plus an auto-generated catalog.json
# under Notes/claude/lazy/upstream/ that lists every flattened resource for
# per-project opt-in via `claude-kit lazy`.
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
# See ./CLAUDE.md → "External Claude Code bundles" for update workflow.
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
    pkgs.runCommand "claude-${kind}-flat" {} ''
      mkdir -p $out

      # --- ruflo ---------------------------------------------------------
      if [ -d "${ruflo}/.claude/${kind}" ]; then
        cd "${ruflo}/.claude/${kind}"
        find . -type f -name '*.md' -print0 \
          | while IFS= read -r -d "" f; do
              rel="''${f#./}"
              name="ruflo--''${rel//\//--}"
              cp -L "$f" "$out/$name"
            done
        cd - >/dev/null
      fi

      # --- wshobson/agents ----------------------------------------------
      if [ -d "${wshobson}/plugins" ]; then
        for plugin_dir in "${wshobson}"/plugins/*/; do
          plugin=$(basename "$plugin_dir")
          src="''${plugin_dir}${kind}"
          [ -d "$src" ] || continue
          find "$src" -maxdepth 1 -type f -name '*.md' -print0 \
            | while IFS= read -r -d "" f; do
                base=$(basename "$f")
                cp -L "$f" "$out/wshobson--''${plugin}--''${base}"
              done
        done
      fi
    '';

  # Build a directory containing one subdirectory per skill, each preserving
  # its SKILL.md + any referenced assets. We then enumerate subdirs for the
  # `skills` attrset.
  skillsDir = pkgs.runCommand "claude-skills-flat" {} ''
    mkdir -p $out

    # --- ruflo .claude/skills/<skill>/SKILL.md -------------------------
    if [ -d "${ruflo}/.claude/skills" ]; then
      for d in "${ruflo}"/.claude/skills/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        cp -rL --no-preserve=mode,ownership "$d" "$out/ruflo--''${name}"
      done
    fi

    # --- wshobson plugins/<plugin>/skills/<skill>/SKILL.md -------------
    if [ -d "${wshobson}/plugins" ]; then
      for plugin_dir in "${wshobson}"/plugins/*/; do
        plugin=$(basename "$plugin_dir")
        skills_root="$plugin_dir"skills
        [ -d "$skills_root" ] || continue
        for d in "$skills_root"/*/; do
          [ -d "$d" ] || continue
          name=$(basename "$d")
          cp -rL --no-preserve=mode,ownership "$d" \
            "$out/wshobson--''${plugin}--''${name}"
        done
      done
    fi
  '';

  agentsDir = mkFlatMarkdown "agents";
  commandsDir = mkFlatMarkdown "commands";

  # Auto-generated catalog.json for the upstream sub-catalog. Lists every
  # resource flattened above plus anthropics-skills. Paths are absolute
  # nix-store paths; claude-kit lazy add symlinks straight to them.
  upstreamCatalog = pkgs.runCommand "claude-upstream-catalog" {
    nativeBuildInputs = [pkgs.jq];
  } ''
    mkdir -p $out

    skills_arr=$(
      {
        for d in ${skillsDir}/*/; do
          [ -d "$d" ] || continue
          name=$(basename "$d")
          jq -n --arg name "$name" --arg path "$d" \
            '{name: $name, path: ($path | sub("/$"; ""))}'
        done
        if [ -d "${anthropicsSkills}/skills" ]; then
          for d in "${anthropicsSkills}"/skills/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            jq -n --arg name "$name" --arg path "$d" \
              '{name: $name, path: ($path | sub("/$"; ""))}'
          done
        fi
      } | jq -s 'sort_by(.name)'
    )

    agents_arr=$(
      for f in ${agentsDir}/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        jq -n --arg name "$name" --arg path "$f" '{name: $name, path: $path}'
      done | jq -s 'sort_by(.name)'
    )

    commands_arr=$(
      for f in ${commandsDir}/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        jq -n --arg name "$name" --arg path "$f" '{name: $name, path: $path}'
      done | jq -s 'sort_by(.name)'
    )

    jq -n \
      --argjson skills "$skills_arr" \
      --argjson agents "$agents_arr" \
      --argjson commands "$commands_arr" \
      '{
        name: "upstream",
        managed: true,
        skills: $skills,
        agents: $agents,
        commands: $commands,
        plugins: []
      }' > $out/catalog.json
  '';
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

  # Symlink the upstream catalog.json into the Notes vault so it lives next
  # to user-curated catalogs and `claude-kit lazy ls` finds it via the same
  # auto-discovery mechanism. The Notes path is outside HM's $HOME tree
  # management (it's a real git repo), so we use an activation script with
  # `ln -sfn` rather than `home.file`.
  home.activation.lazyUpstreamCatalogSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _lazy_upstream="$HOME/killuanix/Notes/claude/lazy/upstream"
    if [ ! -d "$_lazy_upstream" ]; then
      mkdir -p "$_lazy_upstream"
    fi
    ln -sfn "${upstreamCatalog}/catalog.json" "$_lazy_upstream/catalog.json"
  '';
}
