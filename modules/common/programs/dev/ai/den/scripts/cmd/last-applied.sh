# shellcheck shell=bash
den_cmd_last_applied() {
  local out
  out="$(_require_bound)"
  local proj
  proj="$(echo "$out" | sed -n 2p)"
  local ad
  ad="$(_activity_dir "$proj")"
  if [ ! -d "$ad" ]; then
    echo "(no activity)"; return 0
  fi
  printf '%-12s %-25s %-8s %-6s %s\n' HOST WHEN OP DRIFT CWD
  for f in "$ad"/*.jsonl; do
    [ -f "$f" ] || continue
    local h
    h="$(basename "$f" .jsonl)"
    local last
    last="$(tail -1 "$f")"
    [ -n "$last" ] || continue
    local ts op drift cwd
    ts="$(echo "$last" | jq -r '.ts // ""')"
    op="$(echo "$last" | jq -r '.op // ""')"
    drift="$(echo "$last" | jq -r '.drift_after // 0')"
    cwd="$(echo "$last" | jq -r '.cwd // ""')"
    printf '%-12s %-25s %-8s %-6s %s\n' "$h" "$ts" "$op" "$drift" "$cwd"
  done
}
