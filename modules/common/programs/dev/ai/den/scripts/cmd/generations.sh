# shellcheck shell=bash
den_cmd_generations() {
  _bind_ctx
  local root="$BOUND_ROOT"
  local gd
  gd="$(_gen_dir "$root")"
  [ -d "$gd" ] || { echo "(no generations)"; return 0; }
  local cur=
  [ -f "$gd/HEAD" ] && cur="$(cat "$gd/HEAD")"
  printf '%-5s %-25s %-10s %s\n' GEN WHEN OP NOTES_SHA
  for f in "$gd"/gen-*.json; do
    [ -f "$f" ] || continue
    local data
    data="$(cat "$f")"
    local g ts op nsha
    g="$(echo "$data" | jq -r .generation)"
    ts="$(echo "$data" | jq -r .ts)"
    op="$(echo "$data" | jq -r .op)"
    nsha="$(echo "$data" | jq -r '.notes_commit_sha // "—"')"
    local marker=" "
    [ "$g" = "$cur" ] && marker="*"
    printf '%s%-4s %-25s %-10s %s\n' "$marker" "$g" "$ts" "$op" "${nsha:0:12}"
  done
}
