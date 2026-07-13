# shellcheck shell=bash
den_cmd_activate() {
  if ! _try_bind_ctx; then
    # silently emit nothing (eval-friendly)
    return 0
  fi
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local bound_at
  bound_at="$(_meta_get "$root" .bound_at)"
  cat <<EOF
export DEN_PROJECT='$proj'
export DEN_PROJECT_ROOT='$root'
export DEN_BOUND_AT='$bound_at'
export DEN_HOST='$DEN_HOST'
export CLAUDE_PROJECT_DIR='$root'
EOF
}
