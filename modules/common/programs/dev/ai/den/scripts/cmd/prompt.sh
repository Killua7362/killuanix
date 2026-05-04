# shellcheck shell=bash
den_cmd_prompt() {
  local root
  root="$(_find_binding_root 2>/dev/null)" || return 0
  local proj
  proj="$(jq -r .project "$root/.den-meta.json" 2>/dev/null || echo "")"
  [ -z "$proj" ] && return 0
  local drift
  drift="$(jq -r '.lastop.drift_after // 0' "$root/.den-meta.json" 2>/dev/null || echo 0)"
  if [ "$drift" -gt 0 ] 2>/dev/null; then
    printf '%s!%s' "$proj" "$drift"
  else
    printf '%s' "$proj"
  fi
}
