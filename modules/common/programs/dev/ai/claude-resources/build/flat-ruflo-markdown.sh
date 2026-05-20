#!/usr/bin/env bash
# Flatten ruflo .claude/<KIND>/**/*.md into $out as uniquely-named markdown
# files. Per-source catalog: no `ruflo--` prefix.
#
# Inputs:
#   KIND   — "agents" or "commands"
#   RUFLO  — store path of inputs.ruflo
#   out    — runCommand output dir
set -euo pipefail

mkdir -p "$out"

if [ -d "$RUFLO/.claude/$KIND" ]; then
  cd "$RUFLO/.claude/$KIND"
  find . -type f -name '*.md' -print0 \
    | while IFS= read -r -d "" f; do
        rel="${f#./}"
        name="${rel//\//--}"
        cp -L "$f" "$out/$name"
      done
  cd - >/dev/null
fi
