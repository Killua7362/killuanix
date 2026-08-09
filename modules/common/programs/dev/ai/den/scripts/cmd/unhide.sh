# shellcheck shell=bash
# den unhide <path|pattern>... — reverse `den hide`: drop the matching line
# from <project>/.denhidden and reconcile info/exclude. Accepts the same path
# form as `den hide` (resolved + root-anchored) OR an exact pattern string as
# written in .denhidden (for hand-added globs).
den_cmd_unhide() {
  [ $# -gt 0 ] || _err 2 "usage: den unhide <path|pattern>..."
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT" pd
  pd="$(_project_dir_for "$proj")"
  _with_lock "$root" _do_unhide "$root" "$pd" "$@"
}

_do_unhide() {
  local root="$1" pd="$2"; shift 2
  local p rel changed=0
  for p in "$@"; do
    # Try both forms: the exact string given (a hand-written pattern) and the
    # resolved root-anchored path (`/rel`) that `den hide` would have stored.
    _hidden_remove "$pd" "$p"
    if rel="$(_rel_under_root "$root" "$p")" && [ "$rel" != "." ]; then
      _hidden_remove "$pd" "/$rel"
    fi
    echo "  unhidden $p"
    changed=1
  done
  [ "$changed" -eq 1 ] && _hidden_reassert_all "$root" "$pd"
}
