# shellcheck shell=bash
den_cmd_sync() {
  local other="${1:-}"
  [ -n "$other" ] || _err 2 "usage: den sync <OTHER>"
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd from_pd
  pd="$(_project_dir_for "$proj")"
  from_pd="$(_project_dir_for "$other")"
  [ -d "$from_pd" ] || _err 2 "source project not found: $other"

  _run_hook "$pd" "$root" pre-sync || true
  rsync -a --delete --exclude=patches --exclude=.activity \
    "$from_pd/files/" "$pd/files/"
  cp -f "$from_pd/.denignore" "$pd/.denignore" 2>/dev/null || true
  rsync -a "$from_pd/hooks/" "$pd/hooks/" 2>/dev/null || true
  rm -rf "$pd/patches"; mkdir -p "$pd/patches"
  _run_hook "$pd" "$root" post-sync || true
  echo "synced from $other (patches reset to empty)"
}
