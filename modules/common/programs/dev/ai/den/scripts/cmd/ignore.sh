# shellcheck shell=bash
den_cmd_ignore() {
  [ $# -gt 0 ] || _err 2 "usage: den ignore <path>..."
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local pd
  pd="$(_project_dir_for "$proj")"
  _with_lock "$root" _do_ignore "$root" "$pd" "$@"
}

_do_ignore() {
  local root="$1" pd="$2"; shift 2
  for p in "$@"; do
    local rel="$p"
    # update host-only list
    _meta_update "$root" \
      '.host_only |= (. + [$p] | unique)' \
      --arg p "$rel"
    # append to project .denignore (if not already there)
    if ! grep -qxF -- "$rel" "$pd/.denignore" 2>/dev/null; then
      echo "$rel" >>"$pd/.denignore"
    fi
    echo "  ignored $rel"
  done
}
