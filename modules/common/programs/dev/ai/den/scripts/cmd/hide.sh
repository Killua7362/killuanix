# shellcheck shell=bash
# den hide <path|pattern>... — add a gitignore pattern to <project>/.denhidden
# (the source of truth) and reconcile every present repo's info/exclude, so the
# path is kept out of a foreign repo's `git status` WITHOUT being tracked in the
# vault (unlike `den add`). A concrete path is stored root-anchored (`/rel`) so
# only that one location is excluded; a quoted glob (`den hide '*.log'`) is
# anchored under your cwd. Hand-edit `.denhidden` for repo-wide/unanchored
# patterns — `den pull` reconciles them the same way.
den_cmd_hide() {
  [ $# -gt 0 ] || _err 2 "usage: den hide <path|pattern>..."
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT" pd
  pd="$(_project_dir_for "$proj")"
  _with_lock "$root" _do_hide "$root" "$pd" "$@"
}

_do_hide() {
  local root="$1" pd="$2"; shift 2
  local p rel pat changed=0
  for p in "$@"; do
    if ! rel="$(_rel_under_root "$root" "$p")"; then
      _warn "skipping $p (outside binding root)"; continue
    fi
    if [ "$rel" = "." ]; then
      _warn "skipping $p (is the binding root)"; continue
    fi
    pat="/$rel"                       # root-anchored → excludes only this path
    _hidden_record "$pd" "$pat"
    _hidden_record_clone_for "$root" "$pd" "$rel"
    echo "  hidden $pat (git-excluded, not tracked)"
    changed=1
  done
  [ "$changed" -eq 1 ] && _hidden_reassert_all "$root" "$pd"
}
