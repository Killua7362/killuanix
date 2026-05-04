# shellcheck shell=bash
den_cmd_status() {
  local format=text
  local with_diff=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) format=json; shift;;
      --diff) with_diff=1; shift;;
      --verbose|-v) shift;;
      *) shift;;
    esac
  done

  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"

  local data
  data="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd")"

  if [ "$format" = json ]; then
    echo "$data"
  else
    echo "$data" | "$DEN_HELPER_BIN" render-status
  fi
  local drift
  drift="$(echo "$data" | jq -r .drift_count)"
  if [ "$with_diff" = 1 ] && [ "$(echo "$data" | jq -r '."replaced-with-real-file" | length')" -gt 0 ]; then
    echo
    echo "diff (replaced-with-real-file):"
    while IFS= read -r p; do
      echo "  --- project: $pd/files/$p"
      echo "  +++ cwd:     $root/$p"
      diff -u "$pd/files/$p" "$root/$p" || true
    done < <(echo "$data" | jq -r '."replaced-with-real-file"[]')
  fi
  return "$drift"
}
