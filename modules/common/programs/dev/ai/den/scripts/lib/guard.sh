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

# _clone_present_ok: 0 iff clone <cp> is properly materialized for pulling —
# the path exists, is a git work tree, and its origin matches the remote
# recorded in clones.json (an empty recorded remote accepts any origin). Any
# other state (missing / empty dir / not-a-repo / wrong remote) → 1, so `den
# pull` leaves that path completely untouched.
_clone_present_ok() { # <root> <pd> <cp>
  local root="$1" pd="$2" cp="$3" top want cur
  top="$root/$cp"
  [ -e "$top/.git" ] || return 1
  git -C "$top" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  want="$(_clone_remote_for_path "$pd" "$cp")"
  if [ -n "$want" ]; then
    cur="$(git -C "$top" remote get-url origin 2>/dev/null || true)"
    [ "$cur" = "$want" ] || return 1
  fi
  return 0
}

# _clones_scan_repos: emit `<rel>\t<origin-or-empty>` for every git work tree
# under <root> (root itself = ".", plus nested clones), skipping den's own
# `.den/` state dir. Used by `den clone sync|drift`.
_clones_scan_repos() { # <root>
  local root="$1" gp top rel remote
  while IFS= read -r gp; do
    top="$(dirname -- "$gp")"
    if [ "$top" = "$root" ]; then rel="."; else rel="${top#"$root"/}"; fi
    remote="$(git -C "$top" remote get-url origin 2>/dev/null || true)"
    printf '%s\t%s\n' "$rel" "$remote"
  done < <(find "$root" -name .git -not -path '*/.den/*' 2>/dev/null)
}

# _clones_scan_json: the scan as a JSON array [{path,remote}], for the helper.
_clones_scan_json() { # <root>
  _clones_scan_repos "$1" | jq -R -s '
    split("\n") | map(select(length > 0)) | map(split("\t"))
    | map({path: .[0], remote: .[1]})'
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

# ---- hide registry (`den hide`) -----------------------------------------
# `.denhidden` (in the project dir, Notes-side → travels to other hosts) is a
# **gitignore-syntax file, source of truth**, whose patterns are interpreted
# relative to the binding root. It git-excludes paths WITHOUT moving them into
# the vault `files/` store — for artifacts you want kept out of a foreign
# repo's `git status` but not version-controlled by den (e.g. a `.claude/` dir
# a tool generates locally).
#
# den reconciles it declaratively: `_hidden_reassert_all` (on `den pull`, and
# after `den hide`/`unhide`) recomputes, per repo, a **managed block** inside
# that repo's `.git/info/exclude` — purely a function of `.denhidden`, so lines
# den previously wrote but that are no longer present get dropped, while the
# user's own non-block lines in info/exclude are preserved. Pattern→repo
# routing + re-anchoring (a nested clone is a separate gitignore scope) is done
# by the `den-helper hidden-plan` sidecar.

_HIDDEN_BEGIN='# BEGIN den-hidden (managed by `den hide`; edit .denhidden instead)'
_HIDDEN_END='# END den-hidden'

# _rel_under_root: resolve <arg> against the INVOCATION cwd ($PWD) — NOT the
# binding root — so `den hide .claude` from a subdir targets that subdir's
# `.claude`, then express it relative to <root>. Echoes the path-from-root
# (unique per location, so nested `.claude` dirs never collide), "." for the
# root itself, or returns 1 if the target is outside the binding root.
# readlink -f canonicalizes `.`/`..`/symlinks and tolerates a not-yet-created
# leaf (so you can pre-hide a path); a quoted glob arg (`'*.log'`) survives as
# a literal and ends up anchored under the cwd.
_rel_under_root() { # <root> <arg>
  local root="$1" arg="$2" abs
  case "$arg" in
    /*) abs="$(readlink -f "$arg" 2>/dev/null || echo "$arg")";;
    *)  abs="$(readlink -f "$PWD/$arg" 2>/dev/null || echo "$PWD/$arg")";;
  esac
  case "$abs" in
    "$root") printf '.\n';;
    "$root"/*) printf '%s\n' "${abs#"$root"/}";;
    *) return 1;;
  esac
}

# _hidden_record_clone_for: if <rel>'s site sits inside a git tree under the
# binding root, record that repo (path + origin) in clones.json so host-2
# knows to clone it before `den pull` can reassert the exclude. Tolerates a
# not-yet-created leaf. No-op off-repo. Used by `den hide`.
_hidden_record_clone_for() { # <root> <pd> <rel>
  local root="$1" pd="$2" rel="$3" d top clone_path remote
  d="$(dirname -- "$root/$rel")"
  while [ ! -d "$d" ] && [ "$d" != "/" ]; do d="$(dirname -- "$d")"; done
  top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 0
  case "$top/" in
    "$root"/*)
      if [ "$top" = "$root" ]; then clone_path="."; else clone_path="${top#"$root"/}"; fi
      remote="$(git -C "$top" remote get-url origin 2>/dev/null || true)"
      _clones_record "$pd" "$clone_path" "$remote"
      ;;
  esac
}

# ---- .denhidden file I/O (gitignore-syntax patterns, root-relative) ------
_hidden_path() { printf '%s/.denhidden\n' "$1"; }         # arg = project dir

_hidden_list() { # <pd> -> patterns (skip blanks + comments)
  local f; f="$(_hidden_path "$1")"
  [ -f "$f" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$f" || true
}

# _hidden_record: append a pattern if not already present (idempotent).
_hidden_record() { # <pd> <pattern>
  local pd="$1" pat="$2" f
  f="$(_hidden_path "$pd")"
  if ! { [ -f "$f" ] && grep -qxF -- "$pat" "$f"; }; then
    echo "$pat" >>"$f"
  fi
}

# _hidden_remove: drop an exact pattern line from the hide list.
_hidden_remove() { # <pd> <pattern>
  local pd="$1" pat="$2" f tmp
  f="$(_hidden_path "$pd")"
  [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  grep -vxF -- "$pat" "$f" >"$tmp" || true
  mv "$tmp" "$f"
}

# ---- managed-block reconcile into per-repo info/exclude ------------------
# _hidden_expected_block: the managed block text (BEGIN..END) for a set of
# lines, or empty string when there are no lines. Echoes nothing if empty.
_hidden_expected_block() { # <lines-newline-string>
  local lines="$1"
  [ -n "$lines" ] || return 0
  printf '%s\n%s\n%s\n' "$_HIDDEN_BEGIN" "$lines" "$_HIDDEN_END"
}

# _hidden_write_block: rewrite <git-dir>'s info/exclude so its managed block
# exactly matches <lines> (empty <lines> removes the block). User lines
# outside the markers are preserved. Idempotent.
_hidden_write_block() { # <git-dir> <lines-newline-string>
  local gd="$1" lines="$2" excl="$gd/info/exclude" tmp
  mkdir -p "$gd/info"
  tmp="$(mktemp)"
  if [ -f "$excl" ]; then
    sed "/^# BEGIN den-hidden/,/^# END den-hidden/d" "$excl" >"$tmp"
  fi
  if [ -n "$lines" ]; then
    { printf '%s\n' "$_HIDDEN_BEGIN"
      printf '%s\n' "$lines"
      printf '%s\n' "$_HIDDEN_END"; } >>"$tmp"
  fi
  mv "$tmp" "$excl"
}

# _hidden_lines_for_repo: extract repo's line list from the hidden-plan JSON.
_hidden_lines_for_repo() { # <plan-json> <repo>
  printf '%s' "$1" | jq -r --arg r "$2" '(.[$r] // []) | .[]'
}

# _hidden_reassert_all: reconcile every present repo's managed block from
# `.denhidden` (source of truth). Iterates the root repo plus every registered
# clone, so a repo that lost all its patterns has its block cleared too.
_hidden_reassert_all() { # <root> <pd>
  local root="$1" pd="$2" plan repo top gd lines
  plan="$("$DEN_HELPER_BIN" hidden-plan \
    --denhidden "$(_hidden_path "$pd")" \
    --clones "$(_clones_path "$pd")" 2>/dev/null)" || return 0
  # Union of repos to reconcile: "." (root) + every registered clone path.
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    if [ "$repo" = "." ]; then top="$root"; else top="$root/$repo"; fi
    [ -e "$top/.git" ] || continue                 # repo not present here
    gd="$(_guard_git_dir "$top")" || continue
    lines="$(_hidden_lines_for_repo "$plan" "$repo")"
    _hidden_write_block "$gd" "$lines"
  done < <(printf '.\n'; _clones_read "$pd" | jq -r '.clones[]?.path')
}
