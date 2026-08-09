# shellcheck shell=bash
# den clone <verb> — manage the clone registry (<project>/clones.json), the
# list of git repos (path + origin) this project spans, used by `den bootstrap`
# and `den pull`'s clone gate.
den_cmd_clone() {
  local verb="${1:-}"; shift || true
  case "$verb" in
    ""|help|-h|--help) _clone_help;;
    sync)              den_cmd_clone_sync "$@";;
    drift)             den_cmd_clone_drift "$@";;
    *) _err 2 "unknown: den clone $verb" "" "try: den clone";;
  esac
}

_clone_help() {
  cat <<'EOF'
den clone — clone registry (<project>/clones.json) helpers

  den clone sync         scan this project for git repos (incl. nested) and
                         upsert their path+remote into clones.json. Same remote
                         at a new path → appended; a path already present with a
                         DIFFERENT remote → reported as a conflict (fix by hand).
                         Paths are unique; remotes may repeat.
  den clone sync --dry   show what `den clone sync` would change; write nothing.
  den clone drift        report differences between clones.json and what is
                         actually cloned on disk (untracked repos, missing
                         clones, remote mismatches).

Removal is manual — edit clones.json. To materialize the registry on a fresh
host, use `den bootstrap`.
EOF
}

# _clone_plan: emit the reconcile plan JSON (scan disk vs clones.json).
_clone_plan() { # <root> <pd>
  _clones_scan_json "$1" | "$DEN_HELPER_BIN" clone-plan --clones "$(_clones_path "$2")"
}

den_cmd_clone_sync() {
  local dry=0
  case "${1:-}" in --dry|--dry-run) dry=1;; "" ) ;; *) _err 2 "unknown: den clone sync $1";; esac
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT" pd
  pd="$(_project_dir_for "$proj")"
  local plan; plan="$(_clone_plan "$root" "$pd")" || _err 1 "scan failed"

  local nadd nconf nnorem
  nadd="$(echo "$plan" | jq -r '.add | length')"
  nconf="$(echo "$plan" | jq -r '.conflicts | length')"
  nnorem="$(echo "$plan" | jq -r '.noRemote | length')"

  if [ "$dry" -eq 1 ]; then
    echo "den clone sync --dry:"
  fi
  if [ "$nadd" -gt 0 ]; then
    echo "would add:"
    echo "$plan" | jq -r '.add[] | "  + " + .path + "  " + .remote'
    if [ "$dry" -eq 0 ]; then
      while IFS=$'\t' read -r p r; do
        [ -n "$p" ] || continue
        _clones_record "$pd" "$p" "$r"
      done < <(echo "$plan" | jq -r '.add[] | .path + "\t" + .remote')
    fi
  else
    echo "no new repos to add."
  fi

  local rc=0
  if [ "$nconf" -gt 0 ]; then
    echo "conflicts (path already in clones.json with a different remote — resolve by hand):" >&2
    echo "$plan" | jq -r '.conflicts[] | "  ! " + .path + "\n      clones.json: " + (.existing|if .=="" then "<none>" else . end) + "\n      on disk:     " + .found' >&2
    rc=1
  fi
  if [ "$nnorem" -gt 0 ]; then
    echo "no-remote (a present repo has no origin, or a clones.json entry lacks a remote):" >&2
    echo "$plan" | jq -r '.noRemote[] | "  ! " + .' >&2
    rc=1
  fi
  [ "$rc" -eq 0 ] || _info "synced partially — fix the above, then re-run den clone sync"
  return "$rc"
}

den_cmd_clone_drift() {
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT" pd
  pd="$(_project_dir_for "$proj")"
  local plan; plan="$(_clone_plan "$root" "$pd")" || _err 1 "scan failed"

  local any=0
  if [ "$(echo "$plan" | jq -r '.untracked | length')" -gt 0 ]; then
    any=1; echo "untracked (git repo on disk, not in clones.json — run: den clone sync):"
    echo "$plan" | jq -r '.untracked[] | "  + " + .'
  fi
  if [ "$(echo "$plan" | jq -r '.missing | length')" -gt 0 ]; then
    any=1; echo "missing (in clones.json, not cloned here — run: den bootstrap):"
    echo "$plan" | jq -r '.missing[] | "  - " + .'
  fi
  if [ "$(echo "$plan" | jq -r '.conflicts | length')" -gt 0 ]; then
    any=1; echo "remote-drift (path present with a different origin than clones.json):"
    echo "$plan" | jq -r '.conflicts[] | "  ! " + .path + " (clones.json " + (.existing|if .=="" then "<none>" else . end) + " ≠ disk " + .found + ")"'
  fi
  if [ "$(echo "$plan" | jq -r '.noRemote | length')" -gt 0 ]; then
    any=1; echo "no-remote (present repo without origin / entry without remote):"
    echo "$plan" | jq -r '.noRemote[] | "  ! " + .'
  fi
  [ "$any" -eq 0 ] && echo "clones.json in sync with disk." && return 0
  return 1
}
