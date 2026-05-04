#!/usr/bin/env bash
# Flatten ruflo .claude/<KIND>/**/*.md and wshobson plugins/*/<KIND>/*.md
# into $out as uniquely-named markdown files.
#
# Inputs (env vars set by the runCommand wrapper in default.nix):
#   KIND      — "agents" or "commands"
#   RUFLO     — store path of inputs.ruflo
#   WSHOBSON  — store path of inputs.wshobson-agents
#   out       — runCommand output dir (set by Nix)
set -euo pipefail

mkdir -p "$out"

# --- ruflo ---------------------------------------------------------
if [ -d "$RUFLO/.claude/$KIND" ]; then
  cd "$RUFLO/.claude/$KIND"
  find . -type f -name '*.md' -print0 \
    | while IFS= read -r -d "" f; do
        rel="${f#./}"
        name="ruflo--${rel//\//--}"
        cp -L "$f" "$out/$name"
      done
  cd - >/dev/null
fi

# --- wshobson/agents ----------------------------------------------
if [ -d "$WSHOBSON/plugins" ]; then
  for plugin_dir in "$WSHOBSON"/plugins/*/; do
    plugin=$(basename "$plugin_dir")
    src="${plugin_dir}${KIND}"
    [ -d "$src" ] || continue
    find "$src" -maxdepth 1 -type f -name '*.md' -print0 \
      | while IFS= read -r -d "" f; do
          base=$(basename "$f")
          cp -L "$f" "$out/wshobson--${plugin}--${base}"
        done
  done
fi
