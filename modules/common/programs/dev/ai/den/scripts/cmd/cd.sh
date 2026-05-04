# shellcheck shell=bash
den_cmd_cd() {
  local name="${1:-}"
  [ -n "$name" ] || _err 2 "usage: den cd <NAME>"
  _bindings_prune
  local cwds
  cwds="$(_bindings_list_for "$name")"
  if [ -z "$cwds" ]; then
    _err 2 "no bindings for project '$name' on $DEN_HOST" \
      "registry empty for this project" \
      "run 'den init $name' inside a working dir first"
  fi
  local count
  count="$(printf '%s\n' "$cwds" | wc -l)"
  local picked=""
  if [ "$count" = 1 ]; then
    picked="$cwds"
  elif _has_tty && command -v fzf >/dev/null; then
    picked="$(printf '%s\n' "$cwds" | fzf --prompt="den cd $name> ")" \
      || _err 2 "cancelled"
  else
    # Non-TTY: pick the most-recently-pulled (last-applied) one.
    local ad latest=""
    ad="$(_activity_dir "$name")/$DEN_HOST.jsonl"
    if [ -f "$ad" ]; then
      latest="$(tail -1 "$ad" | jq -r '.cwd // ""' 2>/dev/null || echo "")"
    fi
    if [ -n "$latest" ] && printf '%s\n' "$cwds" | grep -qxF -- "$latest"; then
      picked="$latest"
    else
      picked="$(printf '%s\n' "$cwds" | head -n1)"
    fi
  fi
  printf '%s\n' "$picked"
}
