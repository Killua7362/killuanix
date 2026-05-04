#!/usr/bin/env bash
_lazy_project() {
  local include_global=0
  [ "${1:-}" = "--global" ] && include_global=1
  local pdir; pdir=$(_lazy_project_dir)
  if [ ! -d "$pdir" ]; then
    echo "(no .claude/ in $PWD)"
  else
    local kind
    for kind in skills agents commands; do
      local d="$pdir/$kind"
      [ -d "$d" ] || continue
      local items
      items=$(find "$d" -mindepth 1 -maxdepth 1 \( -type l -o -type d -o -type f \) 2>/dev/null \
              | sed 's|.*/||; s|\.md$||' | sort)
      local n; n=$(printf '%s' "$items" | grep -c . || true)
      [ "$n" -gt 0 ] || continue
      echo "=== project $kind ($n) ==="
      printf '%s\n' "$items" | sed 's/^/  /'
    done
    if [ -f "$pdir/settings.local.json" ]; then
      local plugins
      plugins=$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value == true) | .key' "$pdir/settings.local.json" 2>/dev/null || true)
      if [ -n "$plugins" ]; then
        local n; n=$(printf '%s' "$plugins" | grep -c .)
        echo "=== project plugins ($n) ==="
        printf '%s\n' "$plugins" | sed 's/^/  /'
      fi
    fi
  fi
  if [ "$include_global" = 1 ]; then
    echo
    echo "=== globally available (catalog) ==="
    # _lazy_ls is provided by cmd/lazy/ls.sh
    source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/ls.sh"
    _lazy_ls
  fi
}
