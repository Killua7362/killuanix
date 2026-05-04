# shellcheck shell=bash
den_cmd_rm() {
  local force=0
  local -a paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) force=1; shift;;
      *) paths+=("$1"); shift;;
    esac
  done
  [ "${#paths[@]}" -gt 0 ] || _err 2 "usage: den rm <path>..."
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"
  if [ "$force" -ne 1 ]; then
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
    [ -L "$link" ] && rm -f "$link"
    [ -e "$src" ] && rm -f "$src"
    # update meta
    _meta_update "$root" \
      '.symlinks |= map(select(.target != $t))' \
      --arg t "$rel"
    echo "  - $rel"
  done
}
