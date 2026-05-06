# shellcheck shell=bash
den_cmd_new() {
  local name="${1:-}"
  [ -n "$name" ] || _err 2 \
    "usage: den new <NAME> [.|--path P] [--from N] [--preset bare|minimal|claude-full] [--devshell LANG|--no-devshell]"
  shift
  local mode=default arg= preset=claude-full from= devshell= no_devshell=0
  while [ $# -gt 0 ]; do
    case "$1" in
      .) mode=dot; shift;;
      --path) mode=path; arg="${2:-}"; shift 2;;
      --preset) preset="${2:-}"; shift 2;;
      --from) from="${2:-}"; shift 2;;
      --devshell) devshell="${2:-}"; shift 2;;
      --no-devshell) no_devshell=1; shift;;
      *) _err 2 "unexpected: $1";;
    esac
  done
  if [ -n "$devshell" ] && [ "$no_devshell" = "1" ]; then
    _err 2 "--devshell and --no-devshell are mutually exclusive"
  fi
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

  # Resolve dev-shell choice: explicit flag → that lang; --no-devshell → skip;
  # otherwise prompt on TTY (yes/no, then language picker).
  # _err inside _devshell_resolve only exits the command-substitution
  # subshell — capture its rc and propagate so a bad --devshell value
  # aborts before we scaffold and bind a half-built project.
  local lang rc
  lang="$(_devshell_resolve "$devshell" "$no_devshell")"; rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -rf "$pd"
    exit "$rc"
  fi
  if [ -n "$lang" ]; then
    _devshell_apply "$pd" "$lang"
    _info "dev-shell template '$lang' applied to $pd/files/"
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

  # Auto-allow .envrc on TTY so `cd` into the bound dir loads the shell.
  _devshell_post_pull "$TARGET_PATH"
}
