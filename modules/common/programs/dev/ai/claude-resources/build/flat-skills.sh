#!/usr/bin/env bash
# Flatten ruflo + wshobson skill directories into $out, one subdir per skill,
# preserving SKILL.md and any referenced assets.
#
# Inputs:
#   RUFLO     — store path of inputs.ruflo
#   WSHOBSON  — store path of inputs.wshobson-agents
#   out       — runCommand output dir
set -euo pipefail

mkdir -p "$out"

# --- ruflo .claude/skills/<skill>/SKILL.md -------------------------
if [ -d "$RUFLO/.claude/skills" ]; then
  for d in "$RUFLO"/.claude/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    cp -rL --no-preserve=mode,ownership "$d" "$out/ruflo--${name}"
  done
fi

# --- wshobson plugins/<plugin>/skills/<skill>/SKILL.md -------------
if [ -d "$WSHOBSON/plugins" ]; then
  for plugin_dir in "$WSHOBSON"/plugins/*/; do
    plugin=$(basename "$plugin_dir")
    skills_root="${plugin_dir}skills"
    [ -d "$skills_root" ] || continue
    for d in "$skills_root"/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      cp -rL --no-preserve=mode,ownership "$d" \
        "$out/wshobson--${plugin}--${name}"
    done
  done
fi
