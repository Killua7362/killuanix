#!/usr/bin/env bash
# Infer the originating catalog of a resource by name. Walks every lazy
# sub-catalog and prints the first catalog whose skills/agents/commands array
# contains an entry with that name. Falls back to "local" if no catalog
# claims it.
cmd_source() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: claude-kit source <name>"
  local base="${name%.md}"
  for cat_json in "$LAZY_DIR"/*/catalog.json; do
    [ -f "$cat_json" ] || continue
    if jq -e --arg n "$base" \
        '(.skills + .agents + .commands) | map(.name) | index($n)' \
        "$cat_json" >/dev/null 2>&1; then
      basename "$(dirname "$cat_json")"
      return 0
    fi
  done
  echo "local"
}
