# shellcheck shell=bash
den_cmd_clean() {
  local force=0
  case "${1:-}" in --yes|-y) force=1;; esac
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"

  if [ "$force" -ne 1 ]; then
    _yesno "remove all den-managed links for project '$proj' from $root?" || _err 2 "cancelled"
  fi

  _with_lock "$root" _do_clean "$root" "$proj"
}

_do_clean() {
  local root="$1" proj="$2"
  local meta
  meta="$(_meta_path "$root")"
  # Remove only the entries we own. For symlinks, verify the link target
  # resolves under the project's files/. For hardlinks, verify the cwd
  # inode matches the project's inode (otherwise we're looking at an
  # editor-replaced file the user may want to keep).
  local pd
  pd="$(_project_dir_for "$proj")"
  local removed=0
  while IFS= read -r row; do
    local tgt kind
    tgt="$(echo "$row" | jq -r .target)"
    kind="$(echo "$row" | jq -r '.kind // "symlink"')"
    local full="$root/$tgt"
    case "$kind" in
      symlink)
        if [ -L "$full" ]; then
          local actual
          actual="$(readlink -f "$full" 2>/dev/null || true)"
          case "$actual" in
            "$pd/files"/*) rm -f "$full"; removed=$((removed+1));;
            *) _warn "skipping $tgt (link target outside project: $actual)";;
          esac
        fi
        ;;
      hardlink)
        if [ -f "$full" ] && [ ! -L "$full" ]; then
          local cwd_ino src_ino
          cwd_ino="$(stat -c %i "$full" 2>/dev/null || echo 0)"
          src_ino="$(stat -c %i "$pd/files/$tgt" 2>/dev/null || echo 0)"
          if [ "$cwd_ino" = "$src_ino" ] && [ "$cwd_ino" != "0" ]; then
            rm -f "$full"; removed=$((removed+1))
          else
            _warn "skipping $tgt (hardlink broken — cwd inode differs; run 'den re-add' to recover or rm manually)"
          fi
        fi
        ;;
      *)
        _warn "skipping $tgt (unknown kind: $kind)"
        ;;
    esac
  done < <(jq -c '.symlinks[]' "$meta")
  rm -f "$meta" "$root/.den-meta.json.lock"
  # leave .den-meta.json.reflog as recovery breadcrumb
  _record_activity "$proj" clean 0 0
  _append_reflog "$root" clean "$proj" ""
  _bindings_remove "$proj" "$root"
  echo "removed $removed link(s); binding cleared"
  echo "(reflog kept at $root/.den-meta.json.reflog for recovery)"
}
