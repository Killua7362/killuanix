# shellcheck shell=bash
# Leak-guard + clone registry.
#
# den moves a real file into the project's `files/` store and symlinks it back
# in place. When that in-place site sits inside a git work tree (a cloned repo
# you may not own — a corporate remote), the bare symlink shows up in the
# repo's `git status` and one `git add .` would commit + push it to that
# remote. To stop the leak, den appends the site's repo-relative path to the
# repo's `.git/info/exclude` — local-only, never pushed, not itself a tracked
# change. Files that are NOT inside any git tree get no guard (nothing to leak
# to). "Guard any git work tree" — we don't check for a remote; a local-only
# repo is guarded too, so adding a remote later can't retroactively leak.
#
# For a fresh host to know which repos to clone, each guarded add also records
# the containing clone (path relative to the binding root + its origin remote)
# in `<project>/clones.json`, which travels to the other host via the Notes
# vault. `den pull` reads it to gate materialization (don't drop symlinks into
# a not-yet-cloned repo) and to print the `git clone` commands to run.

# ---- git work-tree detection --------------------------------------------
# _guard_repo_top: echo the abs work-tree root containing <site-abs>, or "".
_guard_repo_top() { # <site-abs>
  local site="$1" dir
  dir="$(dirname -- "$site")"
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true
}

# _guard_git_dir: abs .git dir for a work tree (worktree/submodule-safe).
_guard_git_dir() { # <repo-top>
  local top="$1" gd
  gd="$(git -C "$top" rev-parse --git-dir 2>/dev/null)" || return 1
  case "$gd" in /*) ;; *) gd="$top/$gd";; esac
  printf '%s\n' "$gd"
}

# ---- clone registry (<pd>/clones.json) ----------------------------------
_clones_path() { printf '%s/clones.json\n' "$1"; }        # arg = project dir

_clones_read() { # <pd> -> JSON object ({"clones":[]} if absent)
  local f; f="$(_clones_path "$1")"
  [ -f "$f" ] && cat "$f" || echo '{"clones":[]}'
}

# _clones_record: upsert one clone (keyed by path). Idempotent.
_clones_record() { # <pd> <path> <remote>
  local pd="$1" path="$2" remote="$3" f tmp
  f="$(_clones_path "$pd")"
  [ -f "$f" ] || echo '{"clones":[]}' >"$f"
  tmp="$(mktemp)"
  if jq --arg p "$path" --arg r "$remote" \
      '.clones = ((.clones // []) | map(select(.path != $p)) + [{path:$p, remote:$r}])' \
      "$f" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$f"
  else
    rm -f "$tmp"; _warn "could not update $f"
  fi
}

# _clone_path_for_rel: longest registered clone path that is a prefix of <rel>
# (relative to the binding root). Echoes "" if the rel is not inside any
# registered clone (a root-scaffolding file). "." (root-is-a-repo) is skipped —
# the root is always present, so it never needs pull-gating.
_clone_path_for_rel() { # <pd> <rel>
  local pd="$1" rel="$2" best="" p
  while IFS= read -r p; do
    [ -n "$p" ] && [ "$p" != "." ] || continue
    case "$rel/" in "$p"/*) [ "${#p}" -gt "${#best}" ] && best="$p";; esac
  done < <(_clones_read "$pd" | jq -r '.clones[]?.path')
  printf '%s\n' "$best"
}

_clone_remote_for_path() { # <pd> <path>
  _clones_read "$1" | jq -r --arg p "$2" '.clones[]?|select(.path==$p)|.remote // ""'
}

# ---- guard operations ----------------------------------------------------
# _guard_after_link: after a site symlink is (re)created, guard it if it lands
# inside a git tree and record the containing clone for host bootstrap.
# Idempotent; no-op when the site is not inside a repo.
_guard_after_link() { # <root> <pd> <rel>
  local root="$1" pd="$2" rel="$3"
  local site="$root/$rel" top rel_in_repo gd excl entry clone_path remote
  top="$(_guard_repo_top "$site")"
  [ -n "$top" ] || return 0                       # not in a git tree → no guard
  rel_in_repo="${site#"$top"/}"
  gd="$(_guard_git_dir "$top")" || return 0
  excl="$gd/info/exclude"; entry="/$rel_in_repo"
  mkdir -p "$(dirname "$excl")"
  if ! { [ -f "$excl" ] && grep -qxF -- "$entry" "$excl"; }; then
    printf '%s\n' "$entry" >>"$excl"
  fi
  # Record the clone only when it lives under the binding root (so host2 can
  # re-create it at the same relative path). A repo that merely *contains* the
  # root (ancestor) is still guarded above but not recordable as a sub-clone.
  case "$top/" in
    "$root"/*)
      if [ "$top" = "$root" ]; then clone_path="."; else clone_path="${top#"$root"/}"; fi
      remote="$(git -C "$top" remote get-url origin 2>/dev/null || true)"
      _clones_record "$pd" "$clone_path" "$remote"
      ;;
  esac
}

# _guard_unlink: drop a site's info/exclude entry (on `den rm`). No-op if the
# site is not inside a repo or the entry is absent.
_guard_unlink() { # <root> <rel>
  local root="$1" rel="$2"
  local site="$root/$rel" top rel_in_repo gd excl entry tmp
  top="$(_guard_repo_top "$site")"
  [ -n "$top" ] || return 0
  rel_in_repo="${site#"$top"/}"
  gd="$(_guard_git_dir "$top")" || return 0
  excl="$gd/info/exclude"; entry="/$rel_in_repo"
  [ -f "$excl" ] || return 0
  tmp="$(mktemp)"
  grep -vxF -- "$entry" "$excl" >"$tmp" || true
  mv "$tmp" "$excl"
}

# _guard_is_guarded: 0 if <rel>'s site is not in a repo (n/a) or is excluded;
# 1 if it sits inside a repo but is NOT excluded (would leak).
_guard_is_guarded() { # <root> <rel>
  local root="$1" rel="$2"
  local site="$root/$rel" top rel_in_repo gd excl
  top="$(_guard_repo_top "$site")"
  [ -n "$top" ] || return 0
  rel_in_repo="${site#"$top"/}"
  gd="$(_guard_git_dir "$top")" || return 0
  excl="$gd/info/exclude"
  [ -f "$excl" ] && grep -qxF -- "/$rel_in_repo" "$excl" && return 0
  return 1
}
