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
