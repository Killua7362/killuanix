# shellcheck shell=bash
den_cmd_re_add() {
  [ $# -gt 0 ] || _err 2 "usage: den re-add <path>..."
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"
  _with_lock "$root" _do_re_add "$root" "$pd" "$@"
}

_do_re_add() {
  local root="$1" pd="$2"; shift 2
  for p in "$@"; do
    local rel="${p#"$root"/}"
    rel="${rel#./}"
    local cwd_real="$root/$rel"
    local src="$pd/files/$rel"
    if [ ! -f "$cwd_real" ] || [ -L "$cwd_real" ]; then
      _warn "$rel: not a real file; skipping"; continue
    fi
    mkdir -p "$(dirname "$src")"
    cp -f "$cwd_real" "$src"
    rm -f "$cwd_real"
    ln -snf "$src" "$cwd_real"
    echo "  re-added $rel"
  done
}
