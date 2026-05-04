# shellcheck shell=bash
den_cmd_add() {
  local force=0 as_dir=0
  local -a paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=1; shift;;
      --as-dir) as_dir=1; shift;;
      --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done;;
      -*) _err 2 "unknown flag: $1";;
      *) paths+=("$1"); shift;;
    esac
  done
  [ "${#paths[@]}" -gt 0 ] || _err 2 "usage: den add <path>... [--force] [--as-dir]"
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  _with_lock "$root" _do_add "$root" "$proj" "$force" "$as_dir" "${paths[@]}"
}

_do_add() {
  local root="$1" proj="$2" force="$3" as_dir="$4"; shift 4
  local pd
  pd="$(_project_dir_for "$proj")"

  # refuse if Notes is dirty in the project subdir (unless --force)
  if [ "$force" -ne 1 ]; then
    if git -C "$DEN_NOTES" status --porcelain "$pd" 2>/dev/null | grep -q .; then
      _err 2 "Notes is dirty in $pd; commit or pass --force"
    fi
  fi

  _run_hook "$pd" "$root" pre-add || true

  for p in "$@"; do
    local abs
    abs="$(cd "$root" && readlink -f "$p" 2>/dev/null || echo "$root/$p")"
    # require path inside the bound root
    case "$abs" in
      "$root"/*) ;;
      *) _warn "skipping $p (outside binding root)"; continue;;
    esac
    local rel="${abs#"$root"/}"

    # ignore-check
    if [ "$force" -ne 1 ] && grep -qF -- "$rel" "$pd/.denignore" 2>/dev/null; then
      _warn "$rel matches .denignore; skipping (use --force to override)"
      continue
    fi

    if [ -d "$abs" ] && [ "$as_dir" -ne 1 ]; then
      # expand to leaf files
      while IFS= read -r f; do
        local frel="${f#"$root"/}"
        _add_one "$root" "$pd" "$frel"
      done < <(find "$abs" -type f)
    else
      _add_one "$root" "$pd" "$rel"
    fi
  done

  # refresh manifest hash + symlinks ledger
  _do_pull "$root" "$proj" 1 0 >/dev/null 2>&1 || true
  _run_hook "$pd" "$root" post-add || true
  echo "added"
}

_add_one() {
  local root="$1" pd="$2" rel="$3"
  local abs="$root/$rel" target_in_proj="$pd/files/$rel"
  if [ ! -e "$abs" ] || [ -L "$abs" ]; then
    _warn "$rel not a real file; skipping"
    return 0
  fi
  mkdir -p "$(dirname "$target_in_proj")"
  # cross-fs check
  local src_dev tgt_dev
  src_dev="$(stat -c %d "$abs" 2>/dev/null || echo 0)"
  tgt_dev="$(stat -c %d "$(dirname "$target_in_proj")" 2>/dev/null || echo 0)"
  if [ "$src_dev" != "$tgt_dev" ]; then
    _warn "$rel: cross-filesystem add (cp+unlink, not atomic)"
    cp -a "$abs" "$target_in_proj"
    rm -f "$abs"
  else
    mv -f "$abs" "$target_in_proj"
  fi
  ln -snf "$target_in_proj" "$abs"
  echo "  + $rel"
}
