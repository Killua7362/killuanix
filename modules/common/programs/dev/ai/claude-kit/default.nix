# `claude-kit` — terminal utility over the declarative Claude Code resources
# installed by ../claude-resources/ (ruflo + wshobson/agents) and the
# Claude Code CLI itself.
#
# Delegates real work to either (a) `claude …` headless subcommands (plugins,
# MCP, prompts) or (b) `jq` over ~/.claude/settings.json (marketplaces). The
# script is a routing layer — it does not reimplement Claude Code's runtime.
#
# `claude-kit lazy` is the per-project opt-in catalog driver (see
# Notes/claude/lazy/README.md). It walks Notes/claude/lazy/<catalog>/catalog.json
# and (en|dis)ables resources by symlinking them into ./.claude/.
#
# `claude-kit plan` is a python sidecar (see ./plan/) — two-stage prompt-to-
# plan tool built via uv2nix. The venv is exposed to the bash wrapper via
# `$CLAUDE_KIT_PLAN_BIN`; `scripts/cmd/plan.sh` just exec's it.
#
# The bash body lives as plain `.sh` files under ./scripts/ so a shell LSP
# can navigate it. `claude-kit.sh` is the dispatch entrypoint; per-subcommand
# files under `cmd/` and shared helpers under `lib/` are sourced lazily.
{
  pkgs,
  inputs,
  ...
}: let
  claudeKitScripts = pkgs.runCommand "claude-kit-scripts" {} ''
    mkdir -p $out
    cp -r ${./scripts}/* $out/
  '';

  claude-kit-plan-env = import ./plan/package.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  };

  claude-kit = pkgs.writeShellApplication {
    name = "claude-kit";
    runtimeInputs = with pkgs; [jq fzf bat coreutils findutils gnused gnugrep yazi];
    text = ''
      export CLAUDE_KIT_LIB_DIR=${claudeKitScripts}
      export CLAUDE_KIT_PLAN_BIN=${claude-kit-plan-env}/bin/claude-kit-plan
      exec bash ${claudeKitScripts}/claude-kit.sh "$@"
    '';
  };
in {
  home.packages = [claude-kit];
}
