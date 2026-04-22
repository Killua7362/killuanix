# `claude-kit` — terminal utility over the declarative Claude Code resources
# installed by ./claude-resources.nix (ruflo + wshobson/agents) and the
# Claude Code CLI itself.
#
# Delegates real work to either (a) `claude …` headless subcommands (plugins,
# MCP, prompts) or (b) `jq` over ~/.claude/settings.json (marketplaces). The
# script is a routing layer — it does not reimplement Claude Code's runtime.
{
  pkgs,
  lib,
  ...
}: let
  claude-kit = pkgs.writeShellApplication {
    name = "claude-kit";
    runtimeInputs = with pkgs; [jq fzf bat coreutils findutils gnused gnugrep];
    # SC2088: the `~/.claude/...` strings on lines 225–227 are display labels
    # passed to `check`, not paths meant to expand.
    excludeShellChecks = ["SC2088"];
    text = ''
      CLAUDE_DIR="''${HOME}/.claude"
      KIT_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-kit"
      SOURCES_DIR="''${KIT_CACHE}/sources"

      usage() {
        cat <<'EOF'
      claude-kit — manage Claude Code agents, commands, skills, plugins, and MCP servers.

      Usage: claude-kit <subcommand> [args]

      Browse installed resources
        list [agents|commands|skills|plugins|mcp|marketplaces|all]
                             List entries. Defaults to `all`.
        show <name>          Print an agent/command/skill's markdown (bat-rendered).
        search [query]       Filter installed resources. With no query, opens an
                             fzf picker with live preview.
        source <name>        Print the originating repo (ruflo / wshobson/<plugin>
                             / local) inferred from the filename prefix.

      Run a slash command headlessly
        run <command> [args] Execute `claude --print "/<command> args"` in cwd.

      Plugins (headless; shells out to `claude plugin …`)
        plugin list
        plugin install   <name>[@marketplace]
        plugin uninstall <name>[@marketplace]
        plugin enable    <name>[@marketplace]
        plugin disable   <name>[@marketplace]
        plugin update    [name]

      Marketplaces (edits ~/.claude/settings.json directly)
        marketplace list
        marketplace add    <name> <github-owner/repo>
        marketplace remove <name>

      MCP servers (pass-through to `claude mcp …`)
        mcp list
        mcp add <name> <command> [args…]
        mcp remove <name>
        mcp test   <name>

      Misc
        ruflo [args…]        Pass-through to the ruflo CLI.
        doctor               Sanity check the install.
        version              Print pinned revs.
        help | -h | --help

      Most resources are named `ruflo--…` (from ruvnet/ruflo) or
      `wshobson--<plugin>--…` (from wshobson/agents). Use those names
      verbatim with `show`, `run`, or Claude Code's slash autocomplete.
      EOF
      }

      die() { echo "claude-kit: $*" >&2; exit 1; }

      _list_agents()   { [ -d "$CLAUDE_DIR/agents" ]   && find "$CLAUDE_DIR/agents"   -maxdepth 1 -type l -o -type f -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort; }
      _list_commands() { [ -d "$CLAUDE_DIR/commands" ] && find "$CLAUDE_DIR/commands" -maxdepth 1 -type l -o -type f -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort; }
      _list_skills()   { [ -d "$CLAUDE_DIR/skills" ]   && find "$CLAUDE_DIR/skills"   -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | sed 's|.*/||' | sort; }

      cmd_list() {
        local kind="''${1:-all}"
        case "$kind" in
          agents)       _list_agents ;;
          commands)     _list_commands ;;
          skills)       _list_skills ;;
          plugins)      claude plugin list ;;
          mcp)          claude mcp list ;;
          marketplaces)
            if [ -f "$CLAUDE_DIR/settings.json" ]; then
              jq -r '(.extraKnownMarketplaces // {}) | to_entries[] | "\(.key)\t\(.value.source.repo // .value.source.url // "(source unknown)")"' "$CLAUDE_DIR/settings.json"
            else
              echo "(no settings.json)"
            fi ;;
          all|"")
            echo "=== agents ($( _list_agents   | wc -l )) ===";   _list_agents
            echo
            echo "=== commands ($( _list_commands | wc -l )) ==="; _list_commands
            echo
            echo "=== skills ($( _list_skills   | wc -l )) ==="; _list_skills ;;
          *) die "unknown kind: $kind (try agents|commands|skills|plugins|mcp|marketplaces)" ;;
        esac
      }

      _resolve_file() {
        local name="$1"
        local base="''${name%.md}"
        if [ -f "$CLAUDE_DIR/agents/''${base}.md" ]; then
          echo "$CLAUDE_DIR/agents/''${base}.md"; return 0
        fi
        if [ -f "$CLAUDE_DIR/commands/''${base}.md" ]; then
          echo "$CLAUDE_DIR/commands/''${base}.md"; return 0
        fi
        if [ -f "$CLAUDE_DIR/skills/''${base}/SKILL.md" ]; then
          echo "$CLAUDE_DIR/skills/''${base}/SKILL.md"; return 0
        fi
        return 1
      }

      cmd_show() {
        local name="''${1:-}"
        [ -n "$name" ] || die "usage: claude-kit show <name>"
        local f
        f=$(_resolve_file "$name") || die "not found: $name"
        if [ -t 1 ]; then
          bat --style=plain --language=markdown --paging=auto "$f"
        else
          cat "$f"
        fi
      }

      cmd_search() {
        local query="''${1:-}"
        local all
        all=$({
          _list_agents   | sed 's/^/agent   /'
          _list_commands | sed 's/^/command /'
          _list_skills   | sed 's/^/skill   /'
        })
        if [ -z "$query" ]; then
          if [ ! -t 0 ] || [ ! -t 1 ]; then
            echo "$all"; return 0
          fi
          echo "$all" | fzf --preview 'claude-kit show {2}' \
                            --preview-window=right:60%:wrap \
                            --header 'Type to filter · Enter to show · Esc to quit'
        else
          echo "$all" | grep -i -- "$query" || { echo "no matches for: $query" >&2; return 1; }
        fi
      }

      cmd_run() {
        local name="''${1:-}"
        [ -n "$name" ] || die "usage: claude-kit run <command> [args…]"
        shift
        exec claude --print "/''${name} $*"
      }

      cmd_plugin() {
        local sub="''${1:-list}"
        shift || true
        case "$sub" in
          install|uninstall|enable|disable|update|list)
            exec claude plugin "$sub" "$@" ;;
          *) die "plugin: unknown subcommand '$sub' (install|uninstall|enable|disable|update|list)" ;;
        esac
      }

      cmd_marketplace() {
        local sub="''${1:-list}"
        shift || true
        local settings="$CLAUDE_DIR/settings.json"
        case "$sub" in
          list)
            if [ -f "$settings" ]; then
              jq -r '(.extraKnownMarketplaces // {}) | to_entries[] | "\(.key)\t\(.value.source.repo // .value.source.url // "(source unknown)")"' "$settings"
            else
              echo "(no settings.json)"
            fi ;;
          add)
            local name="''${1:-}" repo="''${2:-}"
            [ -n "$name" ] && [ -n "$repo" ] || die "usage: claude-kit marketplace add <name> <owner/repo>"
            mkdir -p "$(dirname "$settings")"
            [ -f "$settings" ] || echo '{}' > "$settings"
            local tmp
            tmp=$(mktemp)
            jq --arg n "$name" --arg r "$repo" \
               '.extraKnownMarketplaces[$n] = { source: { source: "github", repo: $r } }' \
               "$settings" > "$tmp" && mv "$tmp" "$settings"
            echo "added marketplace: $name → $repo" ;;
          remove)
            local name="''${1:-}"
            [ -n "$name" ] || die "usage: claude-kit marketplace remove <name>"
            [ -f "$settings" ] || die "no settings.json to edit"
            local tmp
            tmp=$(mktemp)
            jq --arg n "$name" 'del(.extraKnownMarketplaces[$n])' "$settings" > "$tmp" && mv "$tmp" "$settings"
            echo "removed marketplace: $name" ;;
          *) die "marketplace: unknown subcommand '$sub' (list|add|remove)" ;;
        esac
      }

      cmd_mcp() { exec claude mcp "$@"; }

      cmd_source() {
        local name="''${1:-}"
        [ -n "$name" ] || die "usage: claude-kit source <name>"
        local base="''${name%.md}"
        case "$base" in
          ruflo--*)    echo "ruflo" ;;
          wshobson--*) rest="''${base#wshobson--}"; echo "wshobson/''${rest%%--*}" ;;
          *)           echo "local" ;;
        esac
      }

      cmd_ruflo() { exec ruflo "$@"; }

      cmd_doctor() {
        local ok=1
        check() {
          if eval "$2" >/dev/null 2>&1; then
            printf '  [ok]   %s\n' "$1"
          else
            printf '  [FAIL] %s\n' "$1"; ok=0
          fi
        }
        echo "claude-kit doctor:"
        check "claude on PATH"                 "command -v claude"
        check "ruflo on PATH"                  "command -v ruflo"
        check "~/.claude/agents populated"     "[ -n \"\$(ls -A \"$CLAUDE_DIR/agents\" 2>/dev/null)\" ]"
        check "~/.claude/commands populated"   "[ -n \"\$(ls -A \"$CLAUDE_DIR/commands\" 2>/dev/null)\" ]"
        check "~/.claude/skills populated"     "[ -n \"\$(ls -A \"$CLAUDE_DIR/skills\" 2>/dev/null)\" ]"
        check "sources cache linked"           "[ -e \"$SOURCES_DIR/agents.link\" ] && [ -e \"$SOURCES_DIR/commands.link\" ] && [ -e \"$SOURCES_DIR/skills.link\" ]"
        [ "$ok" = 1 ]
      }

      cmd_version() {
        cat <<'EOF'
      claude-kit (killuanix flake)
        ruflo rev:    01070ede81fa6fbae93d01c347bec1af5d6c17f0
        wshobson rev: 27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb
      EOF
      }

      main() {
        local sub="''${1:-help}"
        shift || true
        case "$sub" in
          help|-h|--help)       usage ;;
          list|ls)              cmd_list "$@" ;;
          show|cat)             cmd_show "$@" ;;
          search|s|find)        cmd_search "$@" ;;
          run)                  cmd_run "$@" ;;
          plugin|plugins)       cmd_plugin "$@" ;;
          marketplace|market|mp) cmd_marketplace "$@" ;;
          mcp)                  cmd_mcp "$@" ;;
          source|src)           cmd_source "$@" ;;
          ruflo)                cmd_ruflo "$@" ;;
          doctor)               cmd_doctor ;;
          version|-V|--version) cmd_version ;;
          *) echo "claude-kit: unknown subcommand '$sub'" >&2; echo >&2; usage >&2; exit 2 ;;
        esac
      }

      main "$@"
    '';
  };
in {
  home.packages = [claude-kit];
}
