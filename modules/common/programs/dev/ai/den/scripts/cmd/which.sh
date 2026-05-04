# shellcheck shell=bash
den_cmd_which() {
  local p="${1:-}"
  [ -n "$p" ] || _err 2 "usage: den which <abs-path>"
  local abs
  abs="$(readlink -f "$p" 2>/dev/null || echo "$p")"
  # case absolute as needed
  case "$abs" in
    /*) ;;
    *) abs="$(pwd -P)/$abs";;
  esac
  local hit
  hit="$(_bindings_owner "$abs" 2>/dev/null || true)"
  if [ -n "$hit" ]; then
    local proj cwd
    proj="$(printf '%s' "$hit" | cut -f1)"
    cwd="$(printf '%s' "$hit" | cut -f2)"
    printf '%s\t%s\n' "$proj" "$cwd"
    return 0
  fi
  # Fallback: maybe the path itself is a binding root (registry stale).
  if [ -f "$abs/.den-meta.json" ]; then
    local proj
    proj="$(jq -r '.project // ""' "$abs/.den-meta.json" 2>/dev/null)"
    if [ -n "$proj" ]; then
      _bindings_add "$proj" "$abs"
      printf '%s\t%s\n' "$proj" "$abs"
      return 0
    fi
  fi
  echo "(unbound)"
  return 1
}
