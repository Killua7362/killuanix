# shellcheck shell=bash
den_cmd_apply() {
  local series="${1:-}"
  [ -n "$series" ] || _err 2 "usage: den apply <SERIES> [--checkout] [--dry-run] [--reverse] [--continue] [--abort] [--onto <ref>]"
  shift || true
  local checkout=0 dry=0 reverse=0 cont=0 abort=0 onto=
  while [ $# -gt 0 ]; do
    case "$1" in
      --checkout) checkout=1; shift;;
      --dry-run|-n) dry=1; shift;;
      --reverse) reverse=1; shift;;
      --continue) cont=1; shift;;
      --abort) abort=1; shift;;
      --onto) onto="${2:-}"; shift 2;;
      *) shift;;
    esac
  done

  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"
  local sd="$pd/patches/$series"
  [ -d "$sd" ] || _err 2 "series not found: $series"

  cd "$root"
  if [ "$abort" = 1 ]; then
    git am --abort 2>/dev/null || true
    echo "aborted"
    return 0
  fi
  if [ "$cont" = 1 ]; then
    git am --continue
    return $?
  fi

  # parse meta
  local meta_json
  meta_json="$("$DEN_HELPER_BIN" parse-toml --path "$sd/meta.toml")"
  local base remote
  base="$(echo "$meta_json" | jq -r .base_commit)"
  remote="$(echo "$meta_json" | jq -r .remote)"

  if [ "$dry" = 1 ]; then
    echo "would apply: $sd"
    for p in "$sd"/*.patch; do
      [ -f "$p" ] || continue
      git apply --check --3way "$p" || true
    done
    return 0
  fi

  if [ "$checkout" = 1 ]; then
    local branch
    branch="$(echo "$meta_json" | jq -r .branch)"
    git fetch "$remote" "$base" 2>/dev/null || _warn "could not fetch $base from $remote"
    git checkout -b "$branch" "$base" 2>/dev/null || git checkout "$branch"
  fi

  if [ "$reverse" = 1 ]; then
    # reverse-apply patches in reverse order
    local -a patches=()
    for p in "$sd"/*.patch; do [ -f "$p" ] && patches+=("$p"); done
    for ((i="${#patches[@]}"-1; i>=0; i--)); do
      git apply -R "${patches[$i]}" || _warn "reverse failed: ${patches[$i]}"
    done
    [ -f "$sd/worktree.diff" ] && git apply -R "$sd/worktree.diff" || true
    [ -f "$sd/index.diff" ] && git apply -R --cached "$sd/index.diff" || true
    echo "reversed series $series"
    return 0
  fi

  # forward apply
  if [ -n "$onto" ]; then
    git fetch "$remote" "$onto" 2>/dev/null || true
  fi
  local target_base="${onto:-$base}"

  # Pre-flight: pull anchor blobs from CAS into git's object DB so
  # `git am --3way` can synthesize 3-way merges even when origin no
  # longer carries the pre-image. Reads Den-Anchor-Blob: trailers
  # injected by `den stash`.
  local restored=0 missing=0
  local p
  for p in "$sd"/*.patch; do
    [ -f "$p" ] || continue
    while IFS= read -r blob; do
      [ -z "$blob" ] && continue
      if _cas_restore_to_git "$blob" 2>/dev/null; then
        restored=$((restored + 1))
      else
        missing=$((missing + 1))
      fi
    done < <(grep -E '^Den-Anchor-Blob: ' "$p" | awk '{print $2}')
  done
  if [ "$restored" -gt 0 ]; then
    _info "restored $restored anchor blob(s) from CAS"
  fi
  if [ "$missing" -gt 0 ]; then
    _warn "$missing anchor blob(s) not in CAS — 3-way merge may fail; consider \`den apply $series --onto <ref>\`"
  fi

  if ls "$sd"/*.patch >/dev/null 2>&1; then
    # If `--onto` is set, we have to rewind first or git am will refuse.
    if [ -n "$onto" ] && [ "$onto" != "$base" ]; then
      local cur
      cur="$(git rev-parse HEAD)"
      if [ "$cur" != "$onto" ]; then
        _info "moving HEAD to --onto $onto before applying"
        git checkout "$onto" 2>/dev/null \
          || _warn "could not checkout $onto; applying onto current HEAD"
      fi
    fi
    git am --3way "$sd"/*.patch || _err 1 "git am failed; resolve and run \`den apply $series --continue\` or --abort"
  fi
  [ -f "$sd/index.diff" ] && git apply --cached "$sd/index.diff"
  [ -f "$sd/worktree.diff" ] && git apply "$sd/worktree.diff"
  [ -f "$sd/untracked.tar" ] && tar -xf "$sd/untracked.tar"
  _record_activity "$proj" apply 0 0
  echo "applied series $series"
}
