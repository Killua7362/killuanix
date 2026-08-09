#!/usr/bin/env bash

# _lazy_apply_plugin <name>
# Flip `enabledPlugins.<name>=true` in ./.claude/settings.local.json.
# Always idempotent (re-setting true is a no-op).
_lazy_apply_plugin() {
  local name="$1"
  local pdir; pdir=$(_lazy_project_dir)
  mkdir -p "$pdir"
  local sjson="$pdir/settings.local.json"
  [ -f "$sjson" ] || echo '{}' > "$sjson"
  local tmp; tmp=$(mktemp)
  jq --arg n "$name" '.enabledPlugins[$n] = true' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
}

# _lazy_apply_one <type-or-empty> <rawname> [catalog-hint]
# Resolves a catalog item and symlinks it into ./.claude/<type>/.
# <rawname> may carry a "<catalog>:" tag (used as the hint when no
# explicit hint arg is passed); the symlink is always created under the
# bare resource name. An empty <type> auto-detects across skill/agent/
# command. Returns 0 (new symlink), 2 (already present), or the
# _lazy_resolve_one code (64 not-found, 65 ambiguous, 66 wrong-tag).
# `plugin` is delegated to _lazy_apply_plugin (always returns 0).
_lazy_apply_one() {
  local type="$1" rawname="$2" hint="${3:-}"
  [ -n "$rawname" ] || return 64
  case "$type" in
    plugin|plugins) _lazy_apply_plugin "$rawname"; return 0 ;;
  esac
  local name="$rawname"
  if [ -z "$hint" ]; then
    hint=$(_lazy_hint "$rawname")
    name=$(_lazy_barename "$rawname")
  fi
  local rc=0
  _lazy_resolve_one "$type" "$name" "$hint" || rc=$?
  [ "$rc" = 0 ] || return "$rc"
  local pdir; pdir=$(_lazy_project_dir)
  local target=""
  case "$RES_TYPE" in
    skills)   mkdir -p "$pdir/skills";   target="$pdir/skills/$name" ;;
    agents)   mkdir -p "$pdir/agents";   target="$pdir/agents/$name.md" ;;
    commands) mkdir -p "$pdir/commands"; target="$pdir/commands/$name.md" ;;
    *) return 64 ;;
  esac
  if [ -e "$target" ] || [ -L "$target" ]; then return 2; fi
  ln -s "$RES_PATH" "$target"
  return 0
}

_lazy_add() {
  local imperative=0
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      --imperative) imperative=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  _lazy_parse_target "$@" || die "usage: claude-kit lazy add [--imperative] <type> <name>  |  add [<catalog>:]<name>  |  add <catalog>/<type>/<name>"

  # Declarative path: if a claude-kit.nix sits above $PWD, edit it
  # instead of writing symlinks/json straight into ./.claude/.
  local cfg
  if [ "$imperative" = 0 ] && cfg=$(_lazy_find_project_config); then
    local key nixitem
    case "$PARSED_TYPE" in
      plugin|plugins|mcp|mcps)
        # Registry-less types — trust the user, write verbatim.
        key=$(_lazy_type_to_key "$PARSED_TYPE") \
          || die "unknown type: $PARSED_TYPE (try skill|agent|command|plugin|mcp)"
        nixitem="$PARSED_NAME"
        ;;
      skill|skills|agent|agents|command|commands|"")
        # Resource types (or auto-detect): resolve so we know the real
        # list key + validate the optional <catalog>: tag before writing.
        local rc=0
        _lazy_resolve_one "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT" || rc=$?
        [ "$rc" = 0 ] || { _lazy_explain_rc "$rc" "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT"; exit 1; }
        key="$RES_TYPE"   # skills|agents|commands (already the nix list key)
        # Always store the resolved catalog tag ("<catalog>:<name>") even
        # when the name is currently unique — future-proofs the entry so
        # a later duplicate in another catalog can't turn this sync into an
        # ambiguity error.
        nixitem="$RES_CAT:$PARSED_NAME"
        ;;
      *) die "unknown type: $PARSED_TYPE (try skill|agent|command|plugin|mcp)" ;;
    esac
    _project_load_sync
    local rc2=0
    _project_edit_list "$cfg" add "$key" "$nixitem" || rc2=$?
    case "$rc2" in
      0)
        echo "+ $key: $nixitem (edited claude-kit.nix)"
        _project_sync --quiet
        return 0 ;;
      4) echo "already in claude-kit.nix: $key/$nixitem"; return 0 ;;
      *) die "claude-kit.nix edit failed (rc=$rc2)" ;;
    esac
  fi

  # Imperative legacy path — direct symlink / settings.local.json edit.
  if [ "$PARSED_TYPE" = "plugin" ] || [ "$PARSED_TYPE" = "plugins" ]; then
    _lazy_apply_plugin "$PARSED_NAME"
    echo "enabled plugin: $PARSED_NAME"
    return 0
  fi
  local rc=0
  _lazy_apply_one "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT" || rc=$?
  case "$rc" in
    0) echo "enabled ${RES_TYPE:-$PARSED_TYPE}: $PARSED_NAME" ;;
    2) die "already enabled: ${PARSED_TYPE:-resource}/$PARSED_NAME" ;;
    64|65|66) _lazy_explain_rc "$rc" "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT"; exit 1 ;;
    *) die "lazy add: internal error rc=$rc" ;;
  esac
}
