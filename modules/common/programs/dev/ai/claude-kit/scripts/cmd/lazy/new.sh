#!/usr/bin/env bash
_lazy_new() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: claude-kit lazy new <name>"
  local d="$LAZY_DIR/$name"
  [ ! -e "$d" ] || die "$d already exists"
  mkdir -p "$d/skills" "$d/agents" "$d/commands"
  jq -n --arg n "$name" '{name: $n, skills: [], agents: [], commands: [], plugins: []}' > "$d/catalog.json"
  echo "scaffolded: $d"
  echo "drop files in $d/{skills,agents,commands}/, then: claude-kit lazy refresh $name"
}
