# shellcheck shell=bash
den_cmd_init() {
  local name="${1:-}"
  if [ -z "$name" ] && _has_tty && command -v fzf >/dev/null; then
    name="$(den_cmd_list --plain | sed 's/^[* ] //; s/  *.*//' | fzf --prompt='den project> ')" || _err 2 "cancelled"
  fi
  [ -n "$name" ] || _err 2 "usage: den init <NAME> [.|--path P]"
  shift || true
  local mode=default arg=
  while [ $# -gt 0 ]; do
    case "$1" in
      .) mode=dot; shift;;
      --path) mode=path; arg="${2:-}"; shift 2;;
      *) _err 2 "unexpected: $1";;
    esac
  done
  local pd
  pd="$(_project_dir_for "$name")"
  [ -d "$pd" ] || _err 2 "project not found: $name" "$pd does not exist" "create with: den new $name"

  _resolve_target_path "$mode" "$arg"
  [ -d "$TARGET_PATH" ] || mkdir -p "$TARGET_PATH"
  if [ -f "$TARGET_PATH/.den-meta.json" ]; then
    local existing
    existing="$(_meta_get "$TARGET_PATH" .project)"
    if [ "$existing" = "$name" ]; then
      _info "already bound to $name; running pull"
    else
      _err 2 "$TARGET_PATH bound to '$existing' (run 'den clean' first or pick that name)"
    fi
  else
    _meta_init "$TARGET_PATH" "$name"
    _append_reflog "$TARGET_PATH" init "" "$name"
  fi
  _bindings_add "$name" "$TARGET_PATH"
  cd "$TARGET_PATH"
  _do_pull "$TARGET_PATH" "$name"
}
