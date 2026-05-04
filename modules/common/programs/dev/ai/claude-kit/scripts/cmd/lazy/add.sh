#!/usr/bin/env bash
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
