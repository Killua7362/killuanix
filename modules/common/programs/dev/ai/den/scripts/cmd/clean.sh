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
    _yesno "remove all symlinks for project '$proj' from $root?" || _err 2 "cancelled"
  fi

  _with_lock "$root" _do_clean "$root" "$proj"
}

_do_clean() {
  local root="$1" proj="$2"
  local meta
  meta="$(_meta_path "$root")"
  # remove only the symlinks we own (target lives inside Notes/projects/<proj>/files/)
  local pd
  pd="$(_project_dir_for "$proj")"
  local removed=0
  while IFS= read -r tgt; do
    local full="$root/$tgt"
    if [ -L "$full" ]; then
      local actual
      actual="$(readlink -f "$full" 2>/dev/null || true)"
      case "$actual" in
        "$pd/files"/*) rm -f "$full"; removed=$((removed+1));;
        *) _warn "skipping $tgt (link target outside project: $actual)";;
      esac
    fi
  done < <(jq -r '.symlinks[].target' "$meta")
  rm -f "$meta" "$root/.den-meta.json.lock"
  # leave .den-meta.json.reflog as recovery breadcrumb
  _record_activity "$proj" clean 0 0
  _append_reflog "$root" clean "$proj" ""
  _bindings_remove "$proj" "$root"
  echo "removed $removed symlink(s); binding cleared"
  echo "(reflog kept at $root/.den-meta.json.reflog for recovery)"
}
