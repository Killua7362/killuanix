# shellcheck shell=bash
den_cmd_new() {
  local name="${1:-}"
  [ -n "$name" ] || _err 2 "usage: den new <NAME> [.|--path P] [--from OTHER] [--preset bare|minimal|claude-full]"
  shift
  local mode=default arg= preset=claude-full from=
  while [ $# -gt 0 ]; do
    case "$1" in
      .) mode=dot; shift;;
      --path) mode=path; arg="${2:-}"; shift 2;;
      --preset) preset="${2:-}"; shift 2;;
      --from) from="${2:-}"; shift 2;;
      *) _err 2 "unexpected: $1";;
    esac
  done
  _resolve_target_path "$mode" "$arg"
  [ -d "$TARGET_PATH" ] || mkdir -p "$TARGET_PATH"
  if [ -f "$TARGET_PATH/.den-meta.json" ]; then
    _err 2 "$TARGET_PATH already bound (run 'den clean' first)"
  fi

  local pd
  pd="$(_scaffold_project "$name" "$preset")"

  if [ -n "$from" ]; then
    local from_pd
    from_pd="$(_project_dir_for "$from")"
    [ -d "$from_pd" ] || _err 2 "source project not found: $from"
    # copy non-patch, non-activity content
    rsync -a --exclude=patches --exclude=.activity \
      "$from_pd/files/" "$pd/files/" 2>/dev/null || true
    [ -f "$from_pd/.denignore" ] && cp "$from_pd/.denignore" "$pd/.denignore"
    [ -f "$from_pd/manifest.toml" ] && cp "$from_pd/manifest.toml" "$pd/manifest.toml"
    [ -d "$from_pd/hooks" ] && rsync -a "$from_pd/hooks/" "$pd/hooks/" 2>/dev/null || true
  fi

  # bind
  _meta_init "$TARGET_PATH" "$name"
  _append_reflog "$TARGET_PATH" new "" "$name"
  _bindings_add "$name" "$TARGET_PATH"
  echo "created project at $pd"
  echo "bound  $TARGET_PATH"
  # Run pull to materialize content
  cd "$TARGET_PATH"
  _do_pull "$TARGET_PATH" "$name"
}
