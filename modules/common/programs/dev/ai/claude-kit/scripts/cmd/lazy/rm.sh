#!/usr/bin/env bash
_lazy_rm() {
  local type="${1:-}" name="${2:-}"
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
