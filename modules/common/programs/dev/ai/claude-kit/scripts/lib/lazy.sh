#!/usr/bin/env bash
# Shared helpers for `claude-kit lazy` — catalog discovery, target parsing,
# and item-finding. Sourced by all cmd/lazy/*.sh files.

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
  bundle ls|show|add|rm|status      Manage named groups (e.g. `bundle add ruflo`)
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
  local type="$1" name="$2" hint="${3:-}"
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
  local first="${1:-}" second="${2:-}"
  PARSED_CAT=""
  PARSED_TYPE=""
  PARSED_NAME=""
  if [ -z "$first" ]; then return 1; fi
  # composite shape contains two slashes
  if printf '%s' "$first" | grep -q '/.*/'; then
    PARSED_CAT="${first%%/*}"
    local rest="${first#*/}"
    PARSED_TYPE="${rest%%/*}"
    PARSED_NAME="${rest#*/}"
  else
    PARSED_TYPE="$first"
    PARSED_NAME="$second"
  fi
  [ -n "$PARSED_TYPE" ] && [ -n "$PARSED_NAME" ]
}

_lazy_project_dir() { echo "$PWD/.claude"; }

_lazy_bundle_files() {
  # Echo `<catalog> <name>` for every bundle JSON in the lazy dir.
  # `find -L` follows symlinks because upstream/bundles is a symlink to
  # a nix-store derivation produced by claude-resources.nix.
  [ -d "$LAZY_DIR" ] || return 0
  find -L "$LAZY_DIR" -mindepth 3 -maxdepth 3 -path '*/bundles/*.json' 2>/dev/null \
    | sed -e "s|^$LAZY_DIR/||" -e 's|/bundles/| |' -e 's|\.json$||' \
    | sort
}

_lazy_bundle_resolve() {
  # _lazy_bundle_resolve <name>  -> echoes "<catalog> <path>" or empty.
  # Accepts <catalog>/<name> or bare <name>.
  local target="$1"
  local hint=""
  if printf '%s' "$target" | grep -q '/'; then
    hint="${target%%/*}"
    target="${target#*/}"
  fi
  local matches=""
  local line c name
  while read -r line; do
    c="${line%% *}"
    name="${line#* }"
    if [ -n "$hint" ] && [ "$c" != "$hint" ]; then continue; fi
    if [ "$name" = "$target" ]; then
      matches="$matches$c $LAZY_DIR/$c/bundles/$name.json"$'\n'
    fi
  done < <(_lazy_bundle_files)
  printf '%s' "$matches"
}

_lazy_bundle_state() { echo "$PWD/.claude/.lazy-bundles.json"; }

# _lazy_find_project_config — walk up from $PWD looking for claude-kit.nix.
# Echoes the absolute path on hit, exits non-zero on miss. Stops at $HOME
# and at filesystem root.
_lazy_find_project_config() {
  local d="$PWD"
  while [ "$d" != "/" ] && [ "$d" != "${HOME%/}" ]; do
    if [ -f "$d/claude-kit.nix" ]; then printf '%s' "$d/claude-kit.nix"; return 0; fi
    d=$(dirname "$d")
  done
  return 1
}

# _lazy_resolve_mcp <name>
# Echo the JSON stanza for an MCP server by name. Looks up two sources in
# order:
#   1. $XDG_DATA_HOME/claude-kit/all-mcp-servers.json — full registry catalog
#      emitted by claude.nix (includes `optional = true` entries excluded
#      from the global mcpServers wiring).
#   2. ~/.claude.json under .mcpServers — runtime servers added via
#      `claude mcp add` or otherwise registered by Claude Code itself.
# Empty output + non-zero rc on miss in both sources.
_lazy_resolve_mcp() {
  local name="$1"
  local catalog="${XDG_DATA_HOME:-$HOME/.local/share}/claude-kit/all-mcp-servers.json"
  local stanza=""
  if [ -f "$catalog" ]; then
    stanza=$(jq -c --arg n "$name" '.[$n] // empty' "$catalog" 2>/dev/null)
  fi
  if [ -z "$stanza" ] && [ -f "$HOME/.claude.json" ]; then
    stanza=$(jq -c --arg n "$name" '.mcpServers[$n] // empty' "$HOME/.claude.json" 2>/dev/null)
  fi
  [ -n "$stanza" ] || return 1
  printf '%s' "$stanza"
}

# _lazy_state_file — flake-managed sync state, sibling of .lazy-bundles.json.
_lazy_state_file() { echo "$PWD/.claude/.flake-managed.json"; }

# _lazy_type_to_key <type-arg> — normalize a CLI type argument (singular or
# plural) into the canonical top-level list key used in claude-kit.nix.
# Echoes the key, exits non-zero on unknown type.
_lazy_type_to_key() {
  case "${1:-}" in
    skill|skills)     echo skills ;;
    agent|agents)     echo agents ;;
    command|commands) echo commands ;;
    plugin|plugins)   echo plugins ;;
    mcp|mcps)         echo mcp ;;
    *) return 1 ;;
  esac
}

# _project_edit_list <claude-kit.nix> <add|rm> <list-key> <item>
# Insert or remove "<item>" inside the top-level `<list-key> = [ ... ];`
# block of a claude-kit.nix file. Schema is flat list-of-strings (see
# den/templates/claude-kit.nix), so a line-oriented awk pass is enough.
# On success the file is rewritten atomically (mktemp+mv) and exit 0.
# Exit codes:
#   2 — list key not present in file
#   3 — list opens and closes on the same line (needs reformat)
#   4 — add: item already present in the block (no-op)
#   5 — add: closing `];` not found (malformed file)
#   6 — rm:  item not present in the block (no-op)
#   1 — other failure
_project_edit_list() {
  local cfg="$1" mode="$2" key="$3" item="$4"
  [ -f "$cfg" ] || { echo "claude-kit.nix not found: $cfg" >&2; return 1; }
  case "$mode" in add|rm) ;; *) echo "_project_edit_list: bad mode '$mode'" >&2; return 1 ;; esac
  case "$key" in skills|agents|commands|plugins|mcp) ;; *) echo "_project_edit_list: bad list key '$key'" >&2; return 1 ;; esac
  [ -n "$item" ] || { echo "_project_edit_list: empty item" >&2; return 1; }

  local tmp; tmp=$(mktemp)
  awk -v mode="$mode" -v key="$key" -v item="$item" '
    BEGIN { state = 0; saw_key = 0; same_line = 0; dup = 0; inserted = 0; removed = 0 }
    state == 0 {
      pat = "^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\\["
      if (match($0, pat)) {
        saw_key = 1
        rest = substr($0, RSTART + RLENGTH)
        if (index(rest, "]") > 0) { same_line = 1; state = 2 } else { state = 1 }
        print
        next
      }
      print
      next
    }
    state == 1 {
      # Closing line of the block: `<indent>];` optionally with trailing # comment.
      if (match($0, "^[[:space:]]*\\];")) {
        if (mode == "add" && !dup) {
          if (match($0, "^[[:space:]]+")) {
            cwhite = substr($0, 1, RLENGTH)
          } else {
            cwhite = ""
          }
          printf "%s  \"%s\"\n", cwhite, item
          inserted = 1
        }
        print
        state = 2
        next
      }
      # Strip leading whitespace + optional trailing comma to compare bare.
      bare = $0
      sub(/^[[:space:]]+/, "", bare)
      sub(/[[:space:]]*,?[[:space:]]*$/, "", bare)
      if (mode == "rm") {
        if (bare == "\"" item "\"") { removed = 1; next }
      }
      if (mode == "add") {
        if (bare !~ /^#/ && bare == "\"" item "\"") dup = 1
      }
      print
      next
    }
    state == 2 { print; next }
    END {
      if (!saw_key)                       exit 10
      if (same_line)                      exit 11
      if (mode == "add" && dup)           exit 12
      if (mode == "add" && !inserted)     exit 13
      if (mode == "rm"  && !removed)      exit 14
    }
  ' "$cfg" > "$tmp"
  local rc=$?
  case "$rc" in
    0)  mv -f "$tmp" "$cfg"; return 0 ;;
    10) rm -f "$tmp"; echo "claude-kit.nix: list '$key' not found in $cfg" >&2; return 2 ;;
    11) rm -f "$tmp"; echo "claude-kit.nix: list '$key' is on a single line; reformat to one entry per line and retry" >&2; return 3 ;;
    12) rm -f "$tmp"; return 4 ;;
    13) rm -f "$tmp"; echo "claude-kit.nix: closing '];' for '$key' not found" >&2; return 5 ;;
    14) rm -f "$tmp"; return 6 ;;
    *)  rm -f "$tmp"; echo "claude-kit.nix: edit failed (awk rc=$rc)" >&2; return 1 ;;
  esac
}

# _project_load_sync — source cmd/project.sh once so _project_sync /
# _project_eval / _project_show etc. are available in this shell. No-op
# if already loaded.
_project_load_sync() {
  if ! declare -F _project_sync >/dev/null; then
    # shellcheck source=../cmd/project.sh
    source "$CLAUDE_KIT_LIB_DIR/cmd/project.sh"
  fi
}
