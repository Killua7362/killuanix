# shellcheck shell=bash
den_cmd_list() {
  local format=plain
  case "${1:-}" in --json) format=json;; --plain) format=plain;; esac

  [ -d "$DEN_PROJECTS" ] || { echo "(no projects in $DEN_PROJECTS)"; return 0; }

  local cur_proj=""
  local root
  if root="$(_find_binding_root)" 2>/dev/null; then
    cur_proj="$(_meta_get "$root" .project 2>/dev/null || true)"
  fi

  if [ "$format" = json ]; then
    local arr="[]"
    for d in "$DEN_PROJECTS"/*/; do
      [ -d "$d" ] || continue
      local manifest="$d/.den-project.toml"
      [ -f "$manifest" ] || continue
      local data
      data="$("$DEN_HELPER_BIN" parse-toml --path "$manifest")"
      local name
      name="$(echo "$data" | jq -r .name)"
      local marked=false
      [ "$name" = "$cur_proj" ] && marked=true
      arr="$(jq --argjson cur "$marked" '. + [$cur as $m | input | . + {bound_here: $m}]' \
        <<<"$arr" <(echo "$data"))" || true
    done
    echo "$arr"
  else
    for d in "$DEN_PROJECTS"/*/; do
      [ -d "$d" ] || continue
      local manifest="$d/.den-project.toml"
      [ -f "$manifest" ] || continue
      local data name vis preset
      data="$("$DEN_HELPER_BIN" parse-toml --path "$manifest")"
      name="$(echo "$data" | jq -r .name)"
      vis="$(echo "$data" | jq -r '.visibility // "public"')"
      preset="$(echo "$data" | jq -r '.preset // "(unknown)"')"
      local marker=" "
      [ "$name" = "$cur_proj" ] && marker="*"
      printf '%s %-30s [%s] %s\n' "$marker" "$name" "$vis" "$preset"
    done
  fi
}
