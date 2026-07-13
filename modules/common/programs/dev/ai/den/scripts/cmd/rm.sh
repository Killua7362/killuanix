# shellcheck shell=bash
den_cmd_rm() {
  local force=0 yes=0
  local -a paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force) force=1; yes=1; shift;;   # -f: skip the commit gate AND the prompt
      --yes|-y)   yes=1; shift;;             # --yes: skip the prompt only (gate still applies)
      *) paths+=("$1"); shift;;
    esac
  done
  [ "${#paths[@]}" -gt 0 ] || _err 2 "usage: den rm <path>... [--yes] [-f]"
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local pd
  pd="$(_project_dir_for "$proj")"

  # Commit gate: each selected target's project content must be tracked + clean
  # in the Notes vault (recoverable from git) — unless -f. Only the selected
  # paths are checked, not the whole vault.
  if [ "$force" -ne 1 ]; then
    local -a dirty=()
    local p rel
    for p in "${paths[@]}"; do
      rel="${p#"$root"/}"; rel="${rel#./}"
      _notes_path_committed "$pd/files/$rel" || dirty+=("$rel")
    done
    if [ "${#dirty[@]}" -gt 0 ]; then
      _err 2 "refusing — not committed/clean in Notes (commit + push, or use -f):" \
        "$(printf '  %s\n' "${dirty[@]}")"
    fi
  fi

  if [ "$yes" -ne 1 ]; then
    _yesno "delete the following from project $proj? (irreversible)"$'\n  '"${paths[*]}" \
      || _err 2 "cancelled"
  fi
  _with_lock "$root" _do_rm "$root" "$pd" "${paths[@]}"
}

_do_rm() {
  local root="$1" pd="$2"; shift 2
  for p in "$@"; do
    local rel="${p#"$root"/}"
    rel="${rel#./}"
    local link="$root/$rel"
    local src="$pd/files/$rel"
    _guard_unlink "$root" "$rel"   # drop the info/exclude entry (no-op if none)
    [ -L "$link" ] && rm -f "$link"
    [ -e "$src" ] && rm -f "$src"
    # update meta
    _meta_update "$root" \
      '.symlinks |= map(select(.target != $t))' \
      --arg t "$rel"
    echo "  - $rel"
  done
}
