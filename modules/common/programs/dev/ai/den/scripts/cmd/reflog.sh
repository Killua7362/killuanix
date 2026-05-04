# shellcheck shell=bash
den_cmd_reflog() {
  local mode=cwd target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --cwd) mode=cwd; shift;;
      --project) mode=project; target="${2:-}"; shift 2;;
      expire) shift; _do_reflog_expire "$@"; return $?;;
      *) shift;;
    esac
  done
  local root
  root="$(_find_binding_root)" || _err 64 "unbound"
  local rl="$root/.den-meta.json.reflog"
  [ -f "$rl" ] || { echo "(empty reflog)"; return 0; }
  "$DEN_HELPER_BIN" read-jsonl --path "$rl" \
    | jq -r '.[] | "\(.ts)  \(.op)  prev=\(.prev_project)  new=\(.new_project)"'
}

_do_reflog_expire() {
  local days=90
  case "${1:-}" in --older-than) days="${2:-90}";; esac
  # Strip 'd' suffix if present.
  days="${days%d}"
  local root
  root="$(_find_binding_root)" || _err 64 "unbound"
  local rl="$root/.den-meta.json.reflog"
  [ -f "$rl" ] || return 0
  local cutoff
  cutoff="$(date -Iseconds -d "$days days ago")"
  local tmp
  tmp="$(mktemp)"
  "$DEN_HELPER_BIN" read-jsonl --path "$rl" \
    | jq --arg c "$cutoff" '[.[] | select(.ts > $c)] | .[] | tostring' -r \
    > "$tmp"
  mv "$tmp" "$rl"
  echo "expired entries older than $days days"
}
