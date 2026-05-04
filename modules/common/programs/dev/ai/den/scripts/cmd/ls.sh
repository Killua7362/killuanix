# shellcheck shell=bash
den_cmd_ls() {
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"

  echo "project: $proj  (cwd: $root)"
  echo
  echo "symlinked from project:"
  jq -r '.symlinks[] | "  " + .target + " -> " + .src' "$(_meta_path "$root")"
  echo
  echo "host-only:"
  jq -r '.host_only[] | "  " + .' "$(_meta_path "$root")"
  echo
  echo "patches in project:"
  if [ -d "$pd/patches" ] && [ -n "$(ls -A "$pd/patches" 2>/dev/null)" ]; then
    for s in "$pd/patches"/*/; do
      [ -d "$s" ] && echo "  $(basename "$s")"
    done
  else
    echo "  (none)"
  fi
  echo
  echo "hooks (shared):"
  if [ -d "$pd/hooks" ] && [ -n "$(ls -A "$pd/hooks" 2>/dev/null)" ]; then
    for h in "$pd/hooks"/*; do
      [ -f "$h" ] && echo "  $(basename "$h")"
    done
  else
    echo "  (none)"
  fi
}
