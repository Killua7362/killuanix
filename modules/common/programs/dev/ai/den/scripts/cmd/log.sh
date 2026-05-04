# shellcheck shell=bash
den_cmd_log() {
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local act
  act="$(_activity_dir "$proj")/$DEN_HOST.jsonl"
  if [ ! -f "$act" ]; then
    echo "(no activity yet)"; return 0
  fi
  "$DEN_HELPER_BIN" read-jsonl --path "$act" --tail 20 \
    | jq -r '.[] | "\(.ts)  \(.op)  exit=\(.exit)  drift=\(.drift_after)"'
}
