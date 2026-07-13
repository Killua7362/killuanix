# shellcheck shell=bash
den_cmd_exec() {
  local name="${1:-}"
  [ -n "$name" ] || _err 2 "usage: den exec <NAME> <cmd>..."
  shift
  # v1: requires running from the bound cwd
  _bind_ctx
  local proj="$BOUND_PROJECT"
  [ "$proj" = "$name" ] || _err 2 "current binding is '$proj', not '$name'"
  "$@"
}
