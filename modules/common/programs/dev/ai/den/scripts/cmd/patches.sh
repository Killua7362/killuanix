# shellcheck shell=bash
den_cmd_patches() {
  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"
  if [ ! -d "$pd/patches" ] || [ -z "$(ls -A "$pd/patches" 2>/dev/null)" ]; then
    echo "(no patches)"; return 0
  fi
  for s in "$pd/patches"/*/; do
    [ -d "$s" ] || continue
    local name
    name="$(basename "$s")"
    local meta="$s/meta.toml"
    local branch="" host="" dirty=""
    if [ -f "$meta" ]; then
      local data
      data="$("$DEN_HELPER_BIN" parse-toml --path "$meta")"
      branch="$(echo "$data" | jq -r '.branch // ""')"
      host="$(echo "$data" | jq -r '.host // ""')"
      dirty="$(echo "$data" | jq -r '.dirty // false')"
    fi
    local n
    n="$(ls "$s"*.patch 2>/dev/null | wc -l)"
    printf '%-30s  %s  %s  patches=%s  dirty=%s\n' "$name" "$branch" "$host" "$n" "$dirty"
  done
}
