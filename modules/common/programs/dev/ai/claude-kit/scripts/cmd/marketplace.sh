#!/usr/bin/env bash
cmd_marketplace() {
  local sub="${1:-list}"
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
      local name="${1:-}" repo="${2:-}"
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
      local name="${1:-}"
      [ -n "$name" ] || die "usage: claude-kit marketplace remove <name>"
      [ -f "$settings" ] || die "no settings.json to edit"
      local tmp
      tmp=$(mktemp)
      jq --arg n "$name" 'del(.extraKnownMarketplaces[$n])' "$settings" > "$tmp" && mv "$tmp" "$settings"
      echo "removed marketplace: $name" ;;
    *) die "marketplace: unknown subcommand '$sub' (list|add|remove)" ;;
  esac
}
