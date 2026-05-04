# shellcheck shell=bash
# Shared utilities: globals, error template, locking, tty, path resolution.

# ---- error template + exit codes -----------------------------------------
# 0 ok / 1 drift / 2 usage / 64 unbound / 65 manifest-corrupt /
# 69 missing-tool / 75 lock-held / 78 config-error
_err() { # _err <code> <what> [why] [hint]
  local code="$1" what="$2" why="${3:-}" hint="${4:-}"
  printf 'error: %s\n' "$what" >&2
  [ -n "$why" ] && printf '  ↳ %s\n' "$why" >&2
  [ -n "$hint" ] && printf '  hint: %s\n' "$hint" >&2
  exit "$code"
}
_die() { _err 1 "$@"; }
_warn() { printf 'warning: %s\n' "$1" >&2; }
_info() { printf '%s\n' "$1" >&2; }

_has_tty() { [ -t 0 ] && [ -t 1 ]; }
_yesno() { # _yesno <prompt>
  local ans
  if ! _has_tty; then return 1; fi
  printf '%s [y/N] ' "$1" >&2
  read -r ans || return 1
  case "$ans" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

# ---- path resolution -----------------------------------------------------
# find_binding_root: walk upward from cwd, return dir containing .den-meta.json
_find_binding_root() {
  local d
  d="$(pwd -P)"
  while [ "$d" != "/" ]; do
    if [ -f "$d/.den-meta.json" ]; then
      printf '%s\n' "$d"
      return 0
    fi
    d="$(dirname -- "$d")"
  done
  return 1
}

# _resolve_target_path: for new/init only; respect git root preference
# args: <maybe-dot-or-pathflag> [path-arg]
# globals set: TARGET_PATH
_resolve_target_path() {
  local mode="${1:-default}" arg="${2:-}"
  case "$mode" in
    dot)
      TARGET_PATH="$(pwd -P)"
      local git_root
      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        if [ "$git_root" != "$TARGET_PATH" ]; then
          _warn "you are inside a git work-tree at $git_root; binding to $TARGET_PATH instead"
          _yesno "proceed?" || _err 2 "cancelled"
        fi
      fi
      ;;
    path)
      [ -n "$arg" ] || _err 2 "--path requires a value"
      if [ "$arg" = "." ]; then
        TARGET_PATH="$(pwd -P)"
      else
        TARGET_PATH="$(cd "$arg" 2>/dev/null && pwd -P)" || TARGET_PATH="$arg"
      fi
      ;;
    *)
      local git_root
      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        TARGET_PATH="$git_root"
      else
        TARGET_PATH="$(pwd -P)"
      fi
      ;;
  esac
}

# ---- locking -------------------------------------------------------------
_with_lock() { # _with_lock <bound-root> <cmd...>
  local root="$1"; shift
  local lock="$root/.den-meta.json.lock"
  mkdir -p "$root"
  exec 9>"$lock" || _err 75 "cannot open lock file $lock"
  if ! flock -n 9; then
    _err 75 "another den process is mutating $root; try again later"
  fi
  "$@"
  local rc=$?
  flock -u 9
  exec 9>&-
  return $rc
}

# ---- zoxide hand-off (opt-in via config) --------------------------------
_maybe_zoxide_add() {
  local root="$1"
  if command -v zoxide >/dev/null 2>&1; then
    zoxide add "$root" 2>/dev/null || true
  fi
}
