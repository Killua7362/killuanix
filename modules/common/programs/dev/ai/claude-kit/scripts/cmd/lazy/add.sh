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

# _lazy_apply_one <type> <name> [catalog-hint]
# Resolves a catalog item and symlinks it into ./.claude/<type>/.
# Returns 0 on success (new symlink), 2 if already present, 64 on
# not-found, 65 on ambiguous match. Caller decides exit policy.
# `plugin` is delegated to _lazy_apply_plugin (always returns 0).
_lazy_apply_one() {
  local type="$1" name="$2" hint="${3:-}"
  [ -n "$type" ] && [ -n "$name" ] || return 64
  case "$type" in
    plugin|plugins) _lazy_apply_plugin "$name"; return 0 ;;
  esac
  local pdir; pdir=$(_lazy_project_dir)
  local matches; matches=$(_lazy_find "$type" "$name" "$hint")
  local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
  if [ "$n" = 0 ] || [ -z "$matches" ]; then return 64; fi
  if [ "$n" -gt 1 ]; then return 65; fi
  local path; path=$(printf '%s' "$matches" | awk '{print $2}')
  local target=""
  case "$type" in
    skill|skills)     mkdir -p "$pdir/skills";   target="$pdir/skills/$name" ;;
    agent|agents)     mkdir -p "$pdir/agents";   target="$pdir/agents/$name.md" ;;
    command|commands) mkdir -p "$pdir/commands"; target="$pdir/commands/$name.md" ;;
    *) return 64 ;;
  esac
  if [ -e "$target" ] || [ -L "$target" ]; then return 2; fi
  ln -s "$path" "$target"
  return 0
}

_lazy_add() {
  _lazy_parse_target "$@" || die "usage: claude-kit lazy add <type> <name>  |  add <catalog>/<type>/<name>"
  if [ "$PARSED_TYPE" = "plugin" ] || [ "$PARSED_TYPE" = "plugins" ]; then
    _lazy_apply_plugin "$PARSED_NAME"
    echo "enabled plugin: $PARSED_NAME"
    return 0
  fi
  local rc=0
  _lazy_apply_one "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT" || rc=$?
  case "$rc" in
    0) echo "enabled $PARSED_TYPE: $PARSED_NAME" ;;
    2) die "already enabled: $PARSED_TYPE/$PARSED_NAME" ;;
    64) die "not found: $PARSED_TYPE/$PARSED_NAME" ;;
    65)
      local matches; matches=$(_lazy_find "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT")
      echo "lazy: multiple matches:" >&2
      printf '%s\n' "$matches" | awk '{print "  " $1 "/" }' >&2
      die "use <catalog>/$PARSED_TYPE/$PARSED_NAME to disambiguate"
      ;;
    *) die "lazy add: internal error rc=$rc" ;;
  esac
}
