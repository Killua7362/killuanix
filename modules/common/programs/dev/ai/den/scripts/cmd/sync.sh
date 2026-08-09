# shellcheck shell=bash
den_cmd_sync() {
  _bind_ctx
  local other="${1:-}"
  [ -n "$other" ] || _err 2 "usage: den sync <OTHER>"
  _reject_hidden_project "$other"
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local pd from_pd
  pd="$(_project_dir_for "$proj")"
  from_pd="$(_project_dir_for "$other")"
  [ -d "$from_pd" ] || _err 2 "source project not found: $other"

  _run_hook "$pd" "$root" pre-sync || true
  rsync -a --delete --exclude=patches --exclude=.activity \
    "$from_pd/files/" "$pd/files/"
  cp -f "$from_pd/.denignore" "$pd/.denignore" 2>/dev/null || true
  rsync -a "$from_pd/hooks/" "$pd/hooks/" 2>/dev/null || true
  # carry the host-bootstrap registries (which repos to clone + what to hide)
  cp -f "$from_pd/clones.json" "$pd/clones.json" 2>/dev/null || true
  cp -f "$from_pd/.denhidden" "$pd/.denhidden" 2>/dev/null || true
  rm -rf "$pd/patches"; mkdir -p "$pd/patches"
  _run_hook "$pd" "$root" post-sync || true
  echo "synced from $other (patches reset to empty)"
}
