#!/usr/bin/env bash
# Flatten wshobson plugins/<plugin>/<KIND>/*.md into $out as uniquely-named
# markdown files. Per-source catalog: outer `wshobson--` prefix dropped; the
# `<plugin>--<base>` shape is preserved so distinct plugins don't collide.
#
# Inputs:
#   KIND      — "agents" or "commands"
#   WSHOBSON  — store path of inputs.wshobson-agents
#   out       — runCommand output dir
set -euo pipefail

mkdir -p "$out"

if [ -d "$WSHOBSON/plugins" ]; then
  for plugin_dir in "$WSHOBSON"/plugins/*/; do
    plugin=$(basename "$plugin_dir")
    src="${plugin_dir}${KIND}"
    [ -d "$src" ] || continue
    find "$src" -maxdepth 1 -type f -name '*.md' -print0 \
      | while IFS= read -r -d "" f; do
          base=$(basename "$f")
          cp -L "$f" "$out/${plugin}--${base}"
        done
  done
fi
