#!/usr/bin/env bash
# Generate a per-source catalog.json. Walks SKILLS_DIR (one subdir per skill),
# AGENTS_DIR and COMMANDS_DIR (flat *.md files). Any of the three may be unset
# or an empty string — that resource type then surfaces as an empty array.
#
# Inputs:
#   NAME           — catalog name (e.g. ruflo, wshobson, anthropics-skills)
#   SKILLS_DIR     — optional; store path containing one subdir per skill
#   AGENTS_DIR     — optional; store path containing *.md agent files
#   COMMANDS_DIR   — optional; store path containing *.md command files
#   out            — runCommand output dir
set -euo pipefail

mkdir -p "$out"

emit_dirs() {
  local d="${1:-}"
  [ -n "$d" ] || return 0
  [ -d "$d" ] || return 0
  for sub in "$d"/*/; do
    [ -d "$sub" ] || continue
    name=$(basename "$sub")
    jq -n --arg name "$name" --arg path "$sub" \
      '{name: $name, path: ($path | sub("/$"; ""))}'
  done
}

emit_files() {
  local d="${1:-}"
  [ -n "$d" ] || return 0
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    jq -n --arg name "$name" --arg path "$f" '{name: $name, path: $path}'
  done
}

skills_arr=$(emit_dirs "${SKILLS_DIR:-}" | jq -s 'sort_by(.name)')
agents_arr=$(emit_files "${AGENTS_DIR:-}" | jq -s 'sort_by(.name)')
commands_arr=$(emit_files "${COMMANDS_DIR:-}" | jq -s 'sort_by(.name)')

jq -n \
  --arg name "$NAME" \
  --argjson skills "$skills_arr" \
  --argjson agents "$agents_arr" \
  --argjson commands "$commands_arr" \
  '{
    name: $name,
    managed: true,
    skills: $skills,
    agents: $agents,
    commands: $commands,
    plugins: []
  }' > "$out/catalog.json"
