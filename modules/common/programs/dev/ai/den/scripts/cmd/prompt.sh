# shellcheck shell=bash
den_cmd_prompt() {
  local root
  root="$(_find_binding_root 2>/dev/null)" || return 0
  local mf; mf="$(_meta_file "$root")"
  local proj
  proj="$(jq -r .project "$mf" 2>/dev/null || echo "")"
  [ -z "$proj" ] && return 0
  local drift
  drift="$(jq -r '.lastop.drift_after // 0' "$mf" 2>/dev/null || echo 0)"
  if [ "$drift" -gt 0 ] 2>/dev/null; then
    printf '%s!%s' "$proj" "$drift"
  else
    printf '%s' "$proj"
  fi
}
