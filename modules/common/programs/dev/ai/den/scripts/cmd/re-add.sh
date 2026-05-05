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
    local kind
    kind="$(_kind_for_rel "$pd" "$rel")"

    # Hardlink fast path: if cwd and project share an inode, the link
    # is intact — nothing to do. cp would error with "same file" and
    # rm would orphan the data.
    if [ "$kind" = "hardlink" ]; then
      local cwd_ino src_ino
      cwd_ino="$(stat -c %i "$cwd_real" 2>/dev/null || echo 0)"
      src_ino="$(stat -c %i "$src" 2>/dev/null || echo 0)"
      if [ "$cwd_ino" = "$src_ino" ] && [ "$cwd_ino" != "0" ]; then
        echo "  re-added $rel (hardlink unchanged)"
        continue
      fi
    fi

    # General path: cwd has the canonical content (post-edit), copy it
    # into the project, then rebuild the link of the configured kind.
    # Use a tempfile + rename so we never reach a state where the
    # project copy is partially written.
    local tmp
    tmp="$(mktemp "$src.XXXXXX")"
    cp -f "$cwd_real" "$tmp"
    mv -f "$tmp" "$src"
    rm -f "$cwd_real"
    _link_for_kind "$kind" "$src" "$cwd_real"
    if [ "$kind" = "hardlink" ]; then
      echo "  re-added $rel (hardlink)"
    else
      echo "  re-added $rel"
    fi
  done
}
