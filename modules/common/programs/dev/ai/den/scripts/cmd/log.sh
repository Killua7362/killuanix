# shellcheck shell=bash
den_cmd_log() {
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local act
  act="$(_activity_dir "$proj")/$DEN_HOST.jsonl"
  if [ ! -f "$act" ]; then
    echo "(no activity yet)"; return 0
  fi
  "$DEN_HELPER_BIN" read-jsonl --path "$act" --tail 20 \
    | jq -r '.[] | "\(.ts)  \(.op)  exit=\(.exit)  drift=\(.drift_after)"'
}
