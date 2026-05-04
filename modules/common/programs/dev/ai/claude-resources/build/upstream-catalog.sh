#!/usr/bin/env bash
# Auto-generate Notes/claude/lazy/upstream/catalog.json — lists every
# flattened resource above plus anthropics-skills entries. Paths are
# absolute nix-store paths so `claude-kit lazy add` symlinks straight
# to them.
#
# Inputs:
#   SKILLS_DIR         — store path of the flat skills dir
#   AGENTS_DIR         — store path of the flat agents dir
#   COMMANDS_DIR       — store path of the flat commands dir
#   ANTHROPICS_SKILLS  — store path of inputs.anthropics-skills
#   out                — runCommand output dir
set -euo pipefail

mkdir -p "$out"

skills_arr=$(
  {
    for d in "$SKILLS_DIR"/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      jq -n --arg name "$name" --arg path "$d" \
        '{name: $name, path: ($path | sub("/$"; ""))}'
    done
    if [ -d "$ANTHROPICS_SKILLS/skills" ]; then
      for d in "$ANTHROPICS_SKILLS"/skills/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        jq -n --arg name "$name" --arg path "$d" \
          '{name: $name, path: ($path | sub("/$"; ""))}'
      done
    fi
  } | jq -s 'sort_by(.name)'
)

agents_arr=$(
  for f in "$AGENTS_DIR"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    jq -n --arg name "$name" --arg path "$f" '{name: $name, path: $path}'
  done | jq -s 'sort_by(.name)'
)

commands_arr=$(
  for f in "$COMMANDS_DIR"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    jq -n --arg name "$name" --arg path "$f" '{name: $name, path: $path}'
  done | jq -s 'sort_by(.name)'
)

jq -n \
  --argjson skills "$skills_arr" \
  --argjson agents "$agents_arr" \
  --argjson commands "$commands_arr" \
  '{
    name: "upstream",
    managed: true,
    skills: $skills,
    agents: $agents,
    commands: $commands,
    plugins: []
  }' > "$out/catalog.json"
