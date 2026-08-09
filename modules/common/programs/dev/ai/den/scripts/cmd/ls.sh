# shellcheck shell=bash
den_cmd_ls() {
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local pd
  pd="$(_project_dir_for "$proj")"

  # Optional PATH arg: scope the listing to files at or under it (relative to
  # the binding root). "." (or no arg from within a subdir) → cwd. Absent → whole binding.
  local prefix="" scoped=0 arg="${1:-}"
  if [ -n "$arg" ]; then
    local abs
    if [ "$arg" = "." ]; then
      abs="$(pwd -P)"
    elif [ -d "$arg" ]; then
      abs="$(cd "$arg" 2>/dev/null && pwd -P)"
    else
      abs="$(cd "$(dirname -- "$arg")" 2>/dev/null && pwd -P)/$(basename -- "$arg")"
    fi
    [ -n "$abs" ] || _err 2 "cannot resolve path: $arg"
    if [ "$abs" = "$root" ]; then
      prefix=""            # whole binding
    else
      case "$abs/" in
        "$root"/*) prefix="${abs#"$root"/}";;
        *) _err 2 "path is outside the binding root ($root): $arg";;
      esac
    fi
    scoped=1
  fi

  echo "project: $proj  (cwd: $root)"
  [ "$scoped" -eq 1 ] && [ -n "$prefix" ] && echo "scope: $prefix/"
  echo
  echo "symlinked from project:"
  jq -r --arg p "$prefix" '
    .symlinks[]
    | select($p == "" or .target == $p or (.target | startswith($p + "/")))
    | "  " + .target + " -> " + .src' "$(_meta_path "$root")"
  echo
  echo "host-only:"
  jq -r --arg p "$prefix" '
    .host_only[]
    | select($p == "" or . == $p or (startswith($p + "/")))
    | "  " + .' "$(_meta_path "$root")"
  echo
  echo "hidden (git-excluded, not tracked):"
  # patterns are gitignore-syntax, root-relative; strip a leading "/" (anchor)
  # for the scope prefix match, but print the pattern verbatim.
  _hidden_list "$pd" | jq -R --arg p "$prefix" '
    (ltrimstr("/")) as $b
    | select($p == "" or $b == $p or ($b | startswith($p + "/")))
    | "  " + .' -r

  # Patches + hooks are project-global (not path-scoped) — only shown for an
  # unscoped listing.
  if [ "$scoped" -eq 0 ]; then
    echo
    echo "patches in project:"
    if [ -d "$pd/patches" ] && [ -n "$(ls -A "$pd/patches" 2>/dev/null)" ]; then
      for s in "$pd/patches"/*/; do
        [ -d "$s" ] && echo "  $(basename "$s")"
      done
    else
      echo "  (none)"
    fi
    echo
    echo "hooks (shared):"
    if [ -d "$pd/hooks" ] && [ -n "$(ls -A "$pd/hooks" 2>/dev/null)" ]; then
      for h in "$pd/hooks"/*; do
        [ -f "$h" ] && echo "  $(basename "$h")"
      done
    else
      echo "  (none)"
    fi
  fi
}
