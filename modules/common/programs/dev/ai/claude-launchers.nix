# Per-invocation Claude Code launchers.
#
# `claude` (the global binary from programs.claude-code) reads from ~/.claude/.
# This module produces sister wrappers — e.g. `claude-algo` — that boot Claude
# Code with a curated extra-skills set on top of the global config, without
# polluting ~/.claude/skills/ for plain `claude` invocations.
#
# Mechanism: each launcher exports CLAUDE_CONFIG_DIR pointing at a state dir
# under $XDG_STATE_HOME/claude-launchers/<name>/. That dir is rebuilt every
# launch — every top-level entry of ~/.claude/ (auth, MCP, agents, commands,
# settings, projects, …) is symlinked in, then skills/ is rebuilt from the
# upstream skill set plus the launcher's curated extras.
#
# Why mirror everything: setting CLAUDE_CONFIG_DIR makes Claude Code read the
# *entire* config from there, including credentials and MCP servers. An empty
# dir would force re-auth and lose every MCP server. Symlinking through is the
# only way to stay additive with the global config.
#
# To add a new launcher, append another `mkClaudeLauncher { … }` to the
# `launchers` list below. To add a skill input, declare it in flake.nix as
# `flake = false` and reference `inputs.<name>` in `extraSkills`.
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  mkClaudeLauncher = {
    name,
    stateName,
    extraSkills,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.findutils];
      text = let
        extraLinks = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            skillName: src: ''ln -sfn ${lib.escapeShellArg (toString src)} "$state_dir/skills/${skillName}"''
          )
          extraSkills
        );
      in ''
        src="$HOME/.claude"
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/claude-launchers/${stateName}"

        mkdir -p "$state_dir/skills"

        # Refresh top-level symlinks pointing at ~/.claude entries (auth,
        # MCP, settings, agents, commands, projects, …). We don't rm the
        # state dir wholesale — Claude Code may have written real files
        # here from a previous session that are worth keeping.
        if [ -d "$src" ]; then
          while IFS= read -r -d "" entry; do
            base=$(basename "$entry")
            [ "$base" = skills ] && continue
            ln -sfn "$entry" "$state_dir/$base"
          done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)
        fi

        # Skills/ is owned by the launcher: clear stale symlinks (real
        # files left untouched), then relink the upstream set.
        find "$state_dir/skills" -mindepth 1 -maxdepth 1 -type l -delete
        if [ -d "$src/skills" ]; then
          while IFS= read -r -d "" entry; do
            ln -sfn "$entry" "$state_dir/skills/$(basename "$entry")"
          done < <(find "$src/skills" -mindepth 1 -maxdepth 1 -print0)
        fi

        # Curated extras — these are the reason this launcher exists.
        ${extraLinks}

        export CLAUDE_CONFIG_DIR="$state_dir"
        exec claude "$@"
      '';
    };

  launchers = [
    (mkClaudeLauncher {
      name = "claude-algo";
      stateName = "algo";
      extraSkills = {
        algo-sensei = inputs.algo-sensei;
      };
    })
  ];
in {
  home.packages = launchers;
}
