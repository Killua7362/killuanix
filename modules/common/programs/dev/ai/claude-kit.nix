# `claude-kit` — terminal utility over the declarative Claude Code resources
# installed by ./claude-resources.nix (ruflo + wshobson/agents) and the
# Claude Code CLI itself.
#
# Delegates real work to either (a) `claude …` headless subcommands (plugins,
# MCP, prompts) or (b) `jq` over ~/.claude/settings.json (marketplaces). The
# script is a routing layer — it does not reimplement Claude Code's runtime.
#
# `claude-kit lazy` is the per-project opt-in catalog driver (see
# Notes/claude/lazy/README.md). It walks Notes/claude/lazy/<catalog>/catalog.json
# and (en|dis)ables resources by symlinking them into ./.claude/.
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
      LAZY_DIR="''${HOME}/killuanix/Notes/claude/lazy"

      usage() {
        cat <<'EOF'
      claude-kit — manage Claude Code agents, commands, skills, plugins, and MCP servers.

      Usage: claude-kit <subcommand> [args]

      Browse installed resources (~/.claude/)
        list [agents|commands|skills|plugins|mcp|marketplaces|all]
                             List entries. Defaults to `all`.
        show <name>          Print an agent/command/skill's markdown (bat-rendered).
        search [query]       Filter installed resources. With no query, opens an
                             fzf picker with live preview.
        source <name>        Print the originating repo (ruflo / wshobson/<plugin>
                             / local) inferred from the filename prefix.

      Per-project lazy catalog (Notes/claude/lazy/)
        lazy ls [<catalog>]                 List sub-catalogs or contents.
        lazy ls --type <kind>               Filter by skills|agents|commands|plugins.
        lazy show <type> <name>             Print item details.
        lazy add  <type> <name>             Symlink into cwd ./.claude/<type>/.
        lazy add  <catalog>/<type>/<name>   Disambiguate when name appears in multiple catalogs.
        lazy rm   <type> <name>             Remove from project scope.
        lazy project [--global]             List project-scope items (--global also shows catalog).
        lazy new <name>                     Scaffold a new sub-catalog dir.
        lazy refresh <name>                 Regenerate <name>/catalog.json from contents.
        lazy doctor                         Validate lazy.json and all catalog.json files.

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
        check "lazy dir present"               "[ -d \"$LAZY_DIR\" ]"
        check "lazy upstream catalog"          "[ -f \"$LAZY_DIR/upstream/catalog.json\" ]"
        [ "$ok" = 1 ]
      }

      cmd_version() {
        cat <<'EOF'
      claude-kit (killuanix flake)
        ruflo rev:    01070ede81fa6fbae93d01c347bec1af5d6c17f0
        wshobson rev: 27a7ed95755a5c3a2948694343a8e2cd7a7ef6fb
      EOF
      }

      # ─────────────────────────────────────────────────────────────────────
      # `claude-kit lazy` — per-project opt-in catalog
      # ─────────────────────────────────────────────────────────────────────

      _lazy_help() {
        cat <<'EOF'
      claude-kit lazy — opt-in catalog of skills, agents, commands, plugins.

        ls [<catalog>] [--type <kind>]    List sub-catalogs or contents
        show <type> <name>                Print item (path + rendered file if md)
        add <type> <name>                 Symlink into ./.claude/<type>/ (project scope)
        add <catalog>/<type>/<name>       Disambiguate when name appears in multiple catalogs
        rm <type> <name>                  Remove from project scope
        project [--global]                List project-scope items (--global also lists catalog)
        new <name>                        Scaffold a new sub-catalog under Notes/claude/lazy/
        refresh <name>                    Regenerate <name>/catalog.json from contents
        doctor                            Validate lazy.json and all catalog.json files
      EOF
      }

      # All sub-catalog names (any subdir of $LAZY_DIR with catalog.json).
      _lazy_catalogs() {
        [ -d "$LAZY_DIR" ] || return 0
        find "$LAZY_DIR" -mindepth 2 -maxdepth 2 -name catalog.json 2>/dev/null \
          | sed -e "s|^$LAZY_DIR/||" -e 's|/catalog.json$||' \
          | sort
      }

      _lazy_count() {
        local c="$1" type="$2"
        jq -r --arg t "$type" '(.[$t] // []) | length' "$LAZY_DIR/$c/catalog.json" 2>/dev/null || echo 0
      }

      # _lazy_find <type> <name> [<hint_catalog>]
      # Echoes "<catalog>\t<path>" lines for matches. Caller decides on
      # ambiguity policy. Type accepts singular or plural.
      _lazy_find() {
        local type="$1" name="$2" hint="''${3:-}"
        local key
        case "$type" in
          skill|skills)     key=skills ;;
          agent|agents)     key=agents ;;
          command|commands) key=commands ;;
          plugin|plugins)   key=plugins ;;
          *) return 64 ;;
        esac
        local c
        for c in $(_lazy_catalogs); do
          if [ -n "$hint" ] && [ "$c" != "$hint" ]; then continue; fi
          local p
          p=$(jq -r --arg k "$key" --arg n "$name" \
                '(.[$k] // []) | map(select(.name == $n)) | .[0].path // empty' \
                "$LAZY_DIR/$c/catalog.json" 2>/dev/null)
          if [ -n "$p" ]; then printf '%s\t%s\n' "$c" "$p"; fi
        done
      }

      # Parse `<catalog>/<type>/<name>` or `<type> <name>` arg shape.
      # Sets globals: PARSED_CAT PARSED_TYPE PARSED_NAME
      _lazy_parse_target() {
        local first="''${1:-}" second="''${2:-}"
        PARSED_CAT=""
        PARSED_TYPE=""
        PARSED_NAME=""
        if [ -z "$first" ]; then return 1; fi
        # composite shape contains two slashes
        if printf '%s' "$first" | grep -q '/.*/'; then
          PARSED_CAT="''${first%%/*}"
          local rest="''${first#*/}"
          PARSED_TYPE="''${rest%%/*}"
          PARSED_NAME="''${rest#*/}"
        else
          PARSED_TYPE="$first"
          PARSED_NAME="$second"
        fi
        [ -n "$PARSED_TYPE" ] && [ -n "$PARSED_NAME" ]
      }

      _lazy_ls() {
        local catalog="" type_filter=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --type) type_filter="''${2:-}"; shift 2 ;;
            -h|--help) _lazy_help; return 0 ;;
            -*) die "lazy ls: unknown flag $1" ;;
            *)  catalog="$1"; shift ;;
          esac
        done

        # Top-level: list catalogs with item counts.
        if [ -z "$catalog" ] && [ -z "$type_filter" ]; then
          local any=0 c
          for c in $(_lazy_catalogs); do
            any=1
            local s a cm p desc=""
            s=$(_lazy_count "$c" skills)
            a=$(_lazy_count "$c" agents)
            cm=$(_lazy_count "$c" commands)
            p=$(_lazy_count "$c" plugins)
            if [ -f "$LAZY_DIR/lazy.json" ]; then
              desc=$(jq -r --arg c "$c" '(.catalogs[$c].description // "")' "$LAZY_DIR/lazy.json" 2>/dev/null)
            fi
            if [ -n "$desc" ]; then
              printf '%-12s skills=%-4s agents=%-4s commands=%-4s plugins=%-3s  %s\n' "$c" "$s" "$a" "$cm" "$p" "$desc"
            else
              printf '%-12s skills=%-4s agents=%-4s commands=%-4s plugins=%-3s\n' "$c" "$s" "$a" "$cm" "$p"
            fi
          done
          [ "$any" = 1 ] || echo "(no catalogs in $LAZY_DIR)"
          return 0
        fi

        # Specific catalog + type filter.
        if [ -n "$catalog" ] && [ -n "$type_filter" ]; then
          [ -f "$LAZY_DIR/$catalog/catalog.json" ] || die "no such catalog: $catalog"
          jq -r --arg t "$type_filter" '(.[$t] // []) | .[] | .name' "$LAZY_DIR/$catalog/catalog.json"
          return 0
        fi

        # Whole catalog (all types).
        if [ -n "$catalog" ]; then
          [ -f "$LAZY_DIR/$catalog/catalog.json" ] || die "no such catalog: $catalog"
          local t
          for t in skills agents commands plugins; do
            local n; n=$(_lazy_count "$catalog" "$t")
            [ "$n" -gt 0 ] || continue
            echo "=== $catalog/$t ($n) ==="
            jq -r --arg t "$t" '(.[$t] // []) | .[] | "  " + .name' "$LAZY_DIR/$catalog/catalog.json"
          done
          return 0
        fi

        # --type across all catalogs.
        if [ -n "$type_filter" ]; then
          local c
          for c in $(_lazy_catalogs); do
            jq -r --arg t "$type_filter" --arg c "$c" \
              '(.[$t] // []) | .[] | "\($c)/" + .name' \
              "$LAZY_DIR/$c/catalog.json"
          done | sort
        fi
      }

      _lazy_show() {
        _lazy_parse_target "$@" || die "usage: claude-kit lazy show <type> <name>  |  show <catalog>/<type>/<name>"
        local matches
        matches=$(_lazy_find "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT")
        local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
        if [ "$n" = 0 ] || [ -z "$matches" ]; then die "not found: $PARSED_TYPE/$PARSED_NAME"; fi
        if [ "$n" -gt 1 ]; then
          echo "lazy: multiple matches:" >&2
          printf '%s\n' "$matches" | awk '{print "  " $1 "/" }' >&2
          die "use <catalog>/$PARSED_TYPE/$PARSED_NAME to disambiguate"
        fi
        local cat path
        cat=$(printf '%s' "$matches" | awk '{print $1}')
        path=$(printf '%s' "$matches" | awk '{print $2}')
        echo "catalog: $cat"
        echo "path:    $path"
        echo
        local file=""
        if [ -d "$path" ] && [ -f "$path/SKILL.md" ]; then file="$path/SKILL.md"
        elif [ -f "$path" ]; then file="$path"; fi
        if [ -n "$file" ]; then
          if [ -t 1 ]; then bat --style=plain --language=markdown --paging=auto "$file"
          else cat "$file"; fi
        fi
      }

      _lazy_project_dir() { echo "$PWD/.claude"; }

      _lazy_add() {
        _lazy_parse_target "$@" || die "usage: claude-kit lazy add <type> <name>  |  add <catalog>/<type>/<name>"
        local pdir; pdir=$(_lazy_project_dir)
        case "$PARSED_TYPE" in
          plugin|plugins)
            mkdir -p "$pdir"
            local sjson="$pdir/settings.local.json"
            [ -f "$sjson" ] || echo '{}' > "$sjson"
            local tmp; tmp=$(mktemp)
            jq --arg n "$PARSED_NAME" '.enabledPlugins[$n] = true' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
            echo "enabled plugin: $PARSED_NAME"
            return 0
            ;;
        esac
        local matches; matches=$(_lazy_find "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT")
        local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
        if [ "$n" = 0 ] || [ -z "$matches" ]; then die "not found: $PARSED_TYPE/$PARSED_NAME"; fi
        if [ "$n" -gt 1 ]; then
          echo "lazy: multiple matches:" >&2
          printf '%s\n' "$matches" | awk '{print "  " $1 "/" }' >&2
          die "use <catalog>/$PARSED_TYPE/$PARSED_NAME to disambiguate"
        fi
        local path; path=$(printf '%s' "$matches" | awk '{print $2}')
        local target=""
        case "$PARSED_TYPE" in
          skill|skills)     mkdir -p "$pdir/skills";   target="$pdir/skills/$PARSED_NAME" ;;
          agent|agents)     mkdir -p "$pdir/agents";   target="$pdir/agents/$PARSED_NAME.md" ;;
          command|commands) mkdir -p "$pdir/commands"; target="$pdir/commands/$PARSED_NAME.md" ;;
          *) die "unknown type: $PARSED_TYPE" ;;
        esac
        if [ -e "$target" ] || [ -L "$target" ]; then die "already enabled: $target"; fi
        ln -s "$path" "$target"
        echo "enabled $PARSED_TYPE: $PARSED_NAME → $target"
      }

      _lazy_rm() {
        local type="''${1:-}" name="''${2:-}"
        [ -n "$type" ] && [ -n "$name" ] || die "usage: claude-kit lazy rm <type> <name>"
        local pdir; pdir=$(_lazy_project_dir)
        local target=""
        case "$type" in
          skill|skills)     target="$pdir/skills/$name" ;;
          agent|agents)     target="$pdir/agents/$name.md" ;;
          command|commands) target="$pdir/commands/$name.md" ;;
          plugin|plugins)
            local sjson="$pdir/settings.local.json"
            [ -f "$sjson" ] || die "no settings.local.json in $pdir"
            local tmp; tmp=$(mktemp)
            jq --arg n "$name" 'del(.enabledPlugins[$n])' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
            echo "disabled plugin: $name"; return 0 ;;
          *) die "unknown type: $type" ;;
        esac
        if [ -L "$target" ] || [ -e "$target" ]; then
          rm "$target"
          echo "disabled $type: $name"
        else
          die "not enabled: $target"
        fi
      }

      _lazy_project() {
        local include_global=0
        [ "''${1:-}" = "--global" ] && include_global=1
        local pdir; pdir=$(_lazy_project_dir)
        if [ ! -d "$pdir" ]; then
          echo "(no .claude/ in $PWD)"
        else
          local kind
          for kind in skills agents commands; do
            local d="$pdir/$kind"
            [ -d "$d" ] || continue
            local items
            items=$(find "$d" -mindepth 1 -maxdepth 1 \( -type l -o -type d -o -type f \) 2>/dev/null \
                    | sed 's|.*/||; s|\.md$||' | sort)
            local n; n=$(printf '%s' "$items" | grep -c . || true)
            [ "$n" -gt 0 ] || continue
            echo "=== project $kind ($n) ==="
            printf '%s\n' "$items" | sed 's/^/  /'
          done
          if [ -f "$pdir/settings.local.json" ]; then
            local plugins
            plugins=$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value == true) | .key' "$pdir/settings.local.json" 2>/dev/null || true)
            if [ -n "$plugins" ]; then
              local n; n=$(printf '%s' "$plugins" | grep -c .)
              echo "=== project plugins ($n) ==="
              printf '%s\n' "$plugins" | sed 's/^/  /'
            fi
          fi
        fi
        if [ "$include_global" = 1 ]; then
          echo
          echo "=== globally available (catalog) ==="
          _lazy_ls
        fi
      }

      _lazy_new() {
        local name="''${1:-}"
        [ -n "$name" ] || die "usage: claude-kit lazy new <name>"
        local d="$LAZY_DIR/$name"
        [ ! -e "$d" ] || die "$d already exists"
        mkdir -p "$d/skills" "$d/agents" "$d/commands"
        jq -n --arg n "$name" '{name: $n, skills: [], agents: [], commands: [], plugins: []}' > "$d/catalog.json"
        echo "scaffolded: $d"
        echo "drop files in $d/{skills,agents,commands}/, then: claude-kit lazy refresh $name"
      }

      _lazy_refresh() {
        local name="''${1:-}"
        [ -n "$name" ] || die "usage: claude-kit lazy refresh <name>"
        local d="$LAZY_DIR/$name"
        [ -d "$d" ] || die "no such catalog: $name"

        _walk_skills() {
          [ -d "$d/skills" ] || { echo '[]'; return; }
          {
            local sd
            for sd in "$d/skills"/*/; do
              [ -d "$sd" ] || continue
              local sn; sn=$(basename "$sd")
              jq -n --arg name "$sn" --arg path "''${sd%/}" '{name: $name, path: $path}'
            done
          } | jq -s 'sort_by(.name)'
        }
        _walk_md() {
          local sub="$1"
          [ -d "$d/$sub" ] || { echo '[]'; return; }
          {
            local f
            for f in "$d/$sub"/*.md; do
              [ -f "$f" ] || continue
              local fn; fn=$(basename "$f" .md)
              jq -n --arg name "$fn" --arg path "$f" '{name: $name, path: $path}'
            done
          } | jq -s 'sort_by(.name)'
        }

        local skills agents commands plugins
        skills=$(_walk_skills)
        agents=$(_walk_md agents)
        commands=$(_walk_md commands)
        if [ -f "$d/catalog.json" ]; then
          plugins=$(jq '.plugins // []' "$d/catalog.json")
        else
          plugins='[]'
        fi
        jq -n --arg name "$name" \
          --argjson skills "$skills" \
          --argjson agents "$agents" \
          --argjson commands "$commands" \
          --argjson plugins "$plugins" \
          '{name: $name, skills: $skills, agents: $agents, commands: $commands, plugins: $plugins}' \
          > "$d/catalog.json"
        echo "refreshed: $d/catalog.json"
      }

      _lazy_doctor() {
        local ok=1
        echo "claude-kit lazy doctor:"
        if [ ! -d "$LAZY_DIR" ]; then
          echo "  [FAIL] $LAZY_DIR does not exist"
          return 1
        fi
        printf '  [ok]   lazy dir: %s\n' "$LAZY_DIR"
        if [ -f "$LAZY_DIR/lazy.json" ]; then
          if jq '.' "$LAZY_DIR/lazy.json" >/dev/null 2>&1; then
            echo "  [ok]   lazy.json valid"
          else
            echo "  [FAIL] lazy.json invalid JSON"; ok=0
          fi
        else
          echo "  [WARN] missing lazy.json (catalog descriptions)"
        fi
        local c
        for c in $(_lazy_catalogs); do
          if jq '.' "$LAZY_DIR/$c/catalog.json" >/dev/null 2>&1; then
            printf '  [ok]   %s/catalog.json\n' "$c"
          else
            printf '  [FAIL] %s/catalog.json invalid\n' "$c"; ok=0
          fi
        done
        [ "$ok" = 1 ]
      }

      cmd_lazy() {
        local verb="''${1:-help}"
        shift || true
        case "$verb" in
          ls|list)            _lazy_ls "$@" ;;
          show|cat)           _lazy_show "$@" ;;
          add|enable)         _lazy_add "$@" ;;
          rm|remove|disable)  _lazy_rm "$@" ;;
          project|proj)       _lazy_project "$@" ;;
          new|scaffold)       _lazy_new "$@" ;;
          refresh|reload)     _lazy_refresh "$@" ;;
          doctor)             _lazy_doctor ;;
          help|-h|--help|"")  _lazy_help ;;
          *) die "lazy: unknown verb '$verb' (try: ls show add rm project new refresh doctor)" ;;
        esac
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
          lazy)                 cmd_lazy "$@" ;;
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
