#!/usr/bin/env bash
# Flatten wshobson plugins/<plugin>/skills/<skill>/ into $out, one subdir per
# skill, preserving SKILL.md and assets. Per-source catalog: outer
# `wshobson--` prefix dropped; `<plugin>--<skill>` shape preserved so distinct
# plugins don't collide.
#
# Inputs:
#   WSHOBSON  — store path of inputs.wshobson-agents
#   out       — runCommand output dir
set -euo pipefail

mkdir -p "$out"

if [ -d "$WSHOBSON/plugins" ]; then
  for plugin_dir in "$WSHOBSON"/plugins/*/; do
    plugin=$(basename "$plugin_dir")
    skills_root="${plugin_dir}skills"
    [ -d "$skills_root" ] || continue
    for d in "$skills_root"/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      cp -rL --no-preserve=mode,ownership "$d" \
        "$out/${plugin}--${name}"
    done
  done
fi
