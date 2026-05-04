# shellcheck shell=bash
# Content-addressed store (CAS) — per-host store at $DEN_CAS_ROOT.
# Stores raw bytes by sha256. Uses git's hash-object format internally only
# when integrating with `git am --3way` — apart from that, content is raw
# and greppable.

_cas_init() {
  mkdir -p "$DEN_CAS_ROOT/objects" "$DEN_CAS_ROOT/refs/patches" \
           "$DEN_CAS_ROOT/refs/anchors"
  [ -f "$DEN_CAS_ROOT/reflog" ] || : >"$DEN_CAS_ROOT/reflog"
}

_cas_path_for() { # _cas_path_for <sha256>
  local s="$1"
  printf '%s/objects/%s/%s\n' "$DEN_CAS_ROOT" "${s:0:2}" "${s:2}"
}

# _cas_put: store stdin or a file; print the sha256 hash on stdout.
_cas_put() { # _cas_put [path]   (stdin if no arg)
  _cas_init
  local tmp
  tmp="$(mktemp)"
  if [ $# -gt 0 ] && [ -f "$1" ]; then
    cp -f "$1" "$tmp"
  else
    cat >"$tmp"
  fi
  local sha
  sha="$(sha256sum "$tmp" | awk '{print $1}')"
  local dest
  dest="$(_cas_path_for "$sha")"
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
  else
    rm -f "$tmp"
  fi
  printf '%s\n' "$sha"
}

_cas_get() { # _cas_get <sha> [outfile]   (stdout if no outfile)
  local sha="$1" out="${2:-}"
  local p
  p="$(_cas_path_for "$sha")"
  if [ ! -f "$p" ]; then
    return 1
  fi
  if [ -n "$out" ]; then
    cp -f "$p" "$out"
  else
    cat "$p"
  fi
}

_cas_has() { # _cas_has <sha>
  [ -f "$(_cas_path_for "$1")" ]
}

# _cas_record_ref: add a refs/patches/<project>/<series>/<n>.ref pointer.
_cas_record_ref() { # _cas_record_ref <project> <series> <n> <sha>
  _cas_init
  local d="$DEN_CAS_ROOT/refs/patches/$1/$2"
  mkdir -p "$d"
  printf '%s\n' "$4" >"$d/$3.ref"
}

# _cas_record_anchor: add an anchor blob ref keyed on the git blob SHA
# so `git am --3way` can recover the pre-image when origin doesn't.
_cas_record_anchor() { # _cas_record_anchor <git-blob-sha1> <cas-sha256>
  _cas_init
  printf '%s\n' "$2" >"$DEN_CAS_ROOT/refs/anchors/$1.ref"
}

_cas_anchor_lookup() { # _cas_anchor_lookup <git-blob-sha1>
  local f="$DEN_CAS_ROOT/refs/anchors/$1.ref"
  [ -f "$f" ] || return 1
  cat "$f"
}

# _cas_restore_to_git: restore an anchor blob into the bound git repo's
# object DB so `git am --3way` can succeed when origin moved on.
_cas_restore_to_git() { # _cas_restore_to_git <git-blob-sha1>
  local git_sha="$1"
  # Already present?
  if git cat-file -e "$git_sha" 2>/dev/null; then
    return 0
  fi
  local cas_sha
  cas_sha="$(_cas_anchor_lookup "$git_sha")" || return 1
  local p
  p="$(_cas_path_for "$cas_sha")"
  [ -f "$p" ] || return 1
  local restored
  restored="$(git hash-object -w "$p" 2>/dev/null)" || return 1
  if [ "$restored" = "$git_sha" ]; then
    return 0
  fi
  # SHA mismatch — anchor was for a different blob; surface but don't
  # corrupt git's object DB (hash-object only writes valid blobs).
  _warn "anchor blob hash mismatch (expected $git_sha, got $restored)"
  return 1
}
