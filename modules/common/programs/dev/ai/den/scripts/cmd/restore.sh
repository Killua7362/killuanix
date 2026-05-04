# shellcheck shell=bash
den_cmd_restore() {
  [ $# -gt 0 ] || _err 2 "usage: den restore <path>..."
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"
  _with_lock "$root" _do_restore "$root" "$pd" "$@"
}

_do_restore() {
  local root="$1" pd="$2"; shift 2
  for p in "$@"; do
    local rel="${p#"$root"/}"
    rel="${rel#./}"
    local link="$root/$rel"
    local src="$pd/files/$rel"
    if [ ! -L "$link" ]; then
      _warn "$rel: not a den-managed symlink; skipping"; continue
    fi
    [ -e "$src" ] || { _warn "$rel: source missing in project"; continue; }
    rm -f "$link"
    mv "$src" "$link"
    _meta_update "$root" \
      '.symlinks |= map(select(.target != $t))' \
      --arg t "$rel"
    echo "  restored $rel (now a real file in cwd; removed from project)"
  done
}
