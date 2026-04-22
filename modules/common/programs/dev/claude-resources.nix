# External Claude Code bundles — ruflo + wshobson/agents flattened into
# ~/.claude/{agents,commands,skills}/.
#
# Naming scheme (keeps Claude Code's flat standalone namespace collision-free):
#   ruflo:                 ruflo--<subpath-with-slashes-as-dashes>.md
#   wshobson/agents:       wshobson--<plugin>--<basename>.md
#   skills (directories):  ruflo--<name>/  and  wshobson--<plugin>--<name>/
#
# The three flat directories are built as pure derivations, then wired into
# Home Manager:
#   - agents + commands:  home.file with `recursive = true` (per-file symlinks,
#                         so user-created files in ~/.claude/{agents,commands}/
#                         aren't clobbered).
#   - skills:             fed into `programs.claude-code.skills` — the upstream
#                         claude-code-nix module handles ~/.claude/skills/.
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

  collectSkills = root:
    lib.mapAttrs'
    (name: _: lib.nameValuePair name "${toString root}/${name}")
    (lib.filterAttrs (_: t: t == "directory") (builtins.readDir root));
in {
  home.file.".claude/agents" = {
    source = agentsDir;
    recursive = true;
  };

  home.file.".claude/commands" = {
    source = commandsDir;
    recursive = true;
  };

  # Attrset-merges with the base set defined in ./claude.nix:133.
  programs.claude-code.skills = collectSkills skillsDir;

  # Expose the built trees via HM-visible paths so claude-kit can walk them
  # without globbing the Nix store. Read-only symlinks; safe to inspect.
  home.file.".cache/claude-kit/sources/agents.link".source = agentsDir;
  home.file.".cache/claude-kit/sources/commands.link".source = commandsDir;
  home.file.".cache/claude-kit/sources/skills.link".source = skillsDir;
}
