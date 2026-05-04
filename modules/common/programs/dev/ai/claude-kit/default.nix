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
# The bash body lives as plain `.sh` files under ./scripts/ so a shell LSP
# can navigate it. `claude-kit.sh` is the dispatch entrypoint; per-subcommand
# files under `cmd/` and shared helpers under `lib/` are sourced lazily.
{pkgs, ...}: let
  claudeKitScripts = pkgs.runCommand "claude-kit-scripts" {} ''
    mkdir -p $out
    cp -r ${./scripts}/* $out/
  '';

  claude-kit = pkgs.writeShellApplication {
    name = "claude-kit";
    runtimeInputs = with pkgs; [jq fzf bat coreutils findutils gnused gnugrep yazi];
    text = ''
      export CLAUDE_KIT_LIB_DIR=${claudeKitScripts}
      exec bash ${claudeKitScripts}/claude-kit.sh "$@"
    '';
  };
in {
  home.packages = [claude-kit];
}
