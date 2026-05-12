#!/usr/bin/env bash
_lazy_rm() {
  local imperative=0
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      --imperative) imperative=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  local type="${1:-}" name="${2:-}"
  [ -n "$type" ] && [ -n "$name" ] || die "usage: claude-kit lazy rm [--imperative] <type> <name>"

  # Declarative path: edit claude-kit.nix in place and re-sync.
  local cfg
  if [ "$imperative" = 0 ] && cfg=$(_lazy_find_project_config); then
    local key; key=$(_lazy_type_to_key "$type") \
      || die "unknown type: $type (try skill|agent|command|plugin|mcp)"
    _project_load_sync
    local rc=0
    _project_edit_list "$cfg" rm "$key" "$name" || rc=$?
    case "$rc" in
      0)
        echo "- $key: $name (edited claude-kit.nix)"
        _project_sync --quiet
        return 0 ;;
      6) echo "not in claude-kit.nix: $key/$name"; return 1 ;;
      *) die "claude-kit.nix edit failed (rc=$rc)" ;;
    esac
  fi

  # Imperative legacy path.
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
