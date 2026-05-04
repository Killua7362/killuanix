#!/usr/bin/env bash
_lazy_refresh() {
  local name="${1:-}"
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
        jq -n --arg name "$sn" --arg path "${sd%/}" '{name: $name, path: $path}'
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
