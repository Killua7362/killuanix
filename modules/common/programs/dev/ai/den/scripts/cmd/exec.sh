# shellcheck shell=bash
den_cmd_exec() {
  local name="${1:-}"
  [ -n "$name" ] || _err 2 "usage: den exec <NAME> <cmd>..."
  shift
  # v1: requires running from the bound cwd
  local out
  out="$(_require_bound)" || _err 2 "must be inside a bound dir"
  local proj
  proj="$(echo "$out" | sed -n 2p)"
  [ "$proj" = "$name" ] || _err 2 "current binding is '$proj', not '$name'"
  "$@"
}
