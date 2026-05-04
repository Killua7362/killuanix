# shellcheck shell=bash
den_cmd_rollback() {
  local target="${1:-HEAD-1}" dry=0
  case "${2:-}" in --dry-run|-n) dry=1;; esac
  _warn "rollback v1 is symlinks-only and does NOT touch the bound git repo"
  _info "to reverse a patch, use: den apply <SERIES> --reverse"
  local out
  out="$(_require_bound)"
  local root
  root="$(echo "$out" | sed -n 1p)"
  local gd
  gd="$(_gen_dir "$root")"
  [ -d "$gd" ] || _err 2 "no generations"
  local cur
  cur="$(cat "$gd/HEAD")"
  local n
  case "$target" in
    HEAD-1) n=$((cur - 1));;
    HEAD) n="$cur";;
    *) n="$target";;
  esac
  local f
  f="$gd/gen-$(printf '%03d' "$n").json"
  [ -f "$f" ] || _err 2 "no such generation: $n"

  if [ "$dry" = 1 ]; then
    echo "would restore symlinks from generation $n"
    jq -r '.symlinks[] | "  + " + .target + " -> " + .src' "$f"
    return 0
  fi

  # naive restore: symlink each entry from the snapshot
  local meta
  meta="$(_meta_path "$root")"
  local proj
  proj="$(jq -r .project "$meta")"
  local pd
  pd="$(_project_dir_for "$proj")"
  while IFS= read -r tgt; do
    local rel="$tgt"
    local src="$pd/files/$rel"
    [ -e "$src" ] || { _warn "$rel: source missing; skipping"; continue; }
    mkdir -p "$(dirname "$root/$rel")"
    ln -snf "$src" "$root/$rel"
    echo "  restored $rel"
  done < <(jq -r '.symlinks[].target' "$f")
  # write a new generation marking the rollback
  _write_generation "$root" rollback
  echo "rolled back to generation $n"
}
