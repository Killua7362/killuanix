# shellcheck shell=bash
den_cmd_init() {
  local name="${1:-}"
  if [ -z "$name" ] && _has_tty && command -v fzf >/dev/null; then
    name="$(den_cmd_list --plain | sed 's/^[* ] //; s/  *.*//' | fzf --prompt='den project> ')" || _err 2 "cancelled"
  fi
  [ -n "$name" ] || _err 2 "usage: den init <NAME> [.|--path P]"
  _reject_hidden_project "$name"
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
  if _den_is_bound_dir "$TARGET_PATH"; then
    local existing
    existing="$(_meta_get "$TARGET_PATH" .project)"
    if [ "$existing" = "$name" ]; then
      _info "already bound to $name"
    else
      _err 2 "$TARGET_PATH bound to '$existing' (run 'den clean' first or pick that name)"
    fi
  else
    _meta_init "$TARGET_PATH" "$name"
    _append_reflog "$TARGET_PATH" init "" "$name"
  fi
  _bindings_add "$name" "$TARGET_PATH"

  # init only binds — it never materializes. The project already exists in the
  # vault (checked above), so tell the user how to populate the working dir.
  echo "bound $TARGET_PATH → project '$name' (exists in vault)"
  if _clones_read "$pd" | jq -e '.clones | length > 0' >/dev/null 2>&1; then
    echo "this project has registered clones — next:"
    echo "  den bootstrap   # print the git clone / mkdir commands for clones.json"
    echo "  den pull        # materialize root + non-clone files (clones stay untouched)"
    echo "then clone repos as needed and re-run 'den pull' to wire each cloned path."
  else
    echo "next: den pull   # materialize the project files into this dir"
  fi
}
