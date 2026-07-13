# shellcheck shell=bash
# `den shelf <verb>` — git-stash-like per-project file shelf. Bare `den shelf`
# lists (never adds by accident). See lib/shelf.sh for the model.
den_cmd_shelf() {
  local sub="${1:-list}"
  case "$sub" in
    add)   shift; _shelf_cmd_add "$@";;
    apply) shift; _shelf_cmd_applypop apply "$@";;
    pop)   shift; _shelf_cmd_applypop pop "$@";;
    drop)  shift; _shelf_cmd_drop "$@";;
    clear) shift; _shelf_cmd_clear "$@";;
    list)  shift; _shelf_cmd_list "$@";;
    help|-h|--help) _shelf_help;;
    *)     _shelf_cmd_list;;   # bare `den shelf` / unknown → list (no accidental add)
  esac
}

_shelf_help() {
  cat <<'EOF'
den shelf — git-stash-like file shelf (per project)

  den shelf add <path>...|.  [--name N]   shelve (remove) matched den files as one row
                                          (`.` = every den file at/under cwd; prompts
                                          for a name if --name is omitted)
  den shelf                               list rows (same as `den shelf list`)
  den shelf list                          rows newest-first, ids like git stash, in a pager
  den shelf apply [id]                    COPY a row's files back (row kept; default id 0)
  den shelf pop   [id]                    MOVE a row's files back (row pruned/deleted)
  den shelf drop  <id>                    delete one row
  den shelf clear [-f]                    wipe the whole archive (needs Notes clean; -f skips)

apply/pop are all-or-nothing: if any file in the row conflicts (target occupied),
the op aborts and lists them without touching anything — shelf the occupant(s), then
re-apply/pop.
EOF
}

_shelf_cmd_add() {
  local name=""
  local -a paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --name|-m) name="${2:-}"; shift 2;;
      --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done;;
      -*) _err 2 "unknown flag: $1";;
      *) paths+=("$1"); shift;;
    esac
  done
  [ "${#paths[@]}" -gt 0 ] || _err 2 "usage: den shelf add <path>...|. [--name NAME]"
  _bind_ctx
  local root="$BOUND_ROOT" pd
  pd="$(_project_dir_for "$BOUND_PROJECT")"
  local -a rels=()
  mapfile -t rels < <(_shelf_resolve_targets "$root" "${paths[@]}")
  [ "${#rels[@]}" -gt 0 ] || _err 2 "no den-managed files matched under: ${paths[*]}"
  # Name is required and non-blank; prompt on a TTY, else demand --name.
  if [ -z "$name" ]; then
    if [ -t 0 ]; then
      while [ -z "$name" ]; do
        printf 'shelf name: ' >&2
        IFS= read -r name || _err 2 "cancelled"
      done
    else
      _err 2 "shelf name required — pass --name NAME (non-interactive)"
    fi
  fi
  _with_lock "$root" _shelf_add "$root" "$pd" "$name" "${rels[@]}"
}

_shelf_cmd_applypop() {
  local verb="$1"; shift
  local id="${1:-0}"
  _bind_ctx
  local root="$BOUND_ROOT" pd
  pd="$(_project_dir_for "$BOUND_PROJECT")"
  _with_lock "$root" _shelf_apply "$root" "$pd" "$id" "$verb"
}

_shelf_cmd_drop() {
  local id="${1:-}"
  [ -n "$id" ] || _err 2 "usage: den shelf drop <id>"
  _bind_ctx
  local root="$BOUND_ROOT" pd
  pd="$(_project_dir_for "$BOUND_PROJECT")"
  _with_lock "$root" _shelf_drop "$pd" "$id"
}

_shelf_cmd_clear() {
  local force=0
  case "${1:-}" in -f|--force) force=1;; esac
  _bind_ctx
  local root="$BOUND_ROOT" pd
  pd="$(_project_dir_for "$BOUND_PROJECT")"
  _with_lock "$root" _shelf_clear "$pd" "$force"
}

_shelf_cmd_list() {
  _bind_ctx
  local pd
  pd="$(_project_dir_for "$BOUND_PROJECT")"
  _shelf_list "$pd"
}
