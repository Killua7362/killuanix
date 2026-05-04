# shellcheck shell=bash
den_cmd_diff() {
  local a="${1:-}" b="${2:-}"
  [ -n "$a" ] || _err 2 "usage: den diff <gen-a> [<gen-b>]"
  local out
  out="$(_require_bound)"
  local root
  root="$(echo "$out" | sed -n 1p)"
  local gd
  gd="$(_gen_dir "$root")"
  local fa="$gd/gen-$(printf '%03d' "$a").json"
  local fb
  if [ -n "$b" ]; then
    fb="$gd/gen-$(printf '%03d' "$b").json"
  else
    fb="$gd/gen-$(printf '%03d' "$(cat "$gd/HEAD")").json"
  fi
  [ -f "$fa" ] || _err 2 "no gen $a"
  [ -f "$fb" ] || _err 2 "no gen $b"
  diff -u <(jq -S . "$fa") <(jq -S . "$fb") || true
}
