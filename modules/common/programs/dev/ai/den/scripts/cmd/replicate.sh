# shellcheck shell=bash
# den replicate [--source <dir>] <target>
#
# Re-creates the source binding's symlinks/hardlinks (from its
# .den-meta.json ledger) inside <target> at the same relative paths,
# without registering <target> as a binding. Used by `wt new` to seed a
# fresh sibling worktree with the den-managed files that live in main
# but aren't tracked by git.
#
# Skips any path that already exists in <target> (so git-checked-out
# files in a fresh worktree are left alone). Hardlinks intentionally
# share an inode with the project source: edits in any replicated
# worktree's hardlinked file will be visible in main and every other
# binding/worktree pointing at that source — a warning is emitted when
# any hardlinks are created.
den_cmd_replicate() {
  local source="" target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --source) source="${2:-}"; shift 2 || _err 2 "--source requires a value" ;;
      --source=*) source="${1#--source=}"; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: den replicate [--source <dir>] <target>

Re-create the source binding's symlinks and hardlinks under <target>.
Source defaults to the current directory. Skips entries that already
exist in <target>. Does not register <target> as a binding.
EOF
        return 0
        ;;
      --) shift; break ;;
      -*) _err 2 "unknown flag: $1" ;;
      *)
        if [ -z "$target" ]; then target="$1"; shift
        else _err 2 "unexpected argument: $1"
        fi
        ;;
    esac
  done
  [ -n "$target" ] || _err 2 "usage: den replicate [--source <dir>] <target>"

  source="${source:-$(pwd -P)}"
  source="$(cd "$source" 2>/dev/null && pwd -P)" || _err 2 "source not a directory: $source"
  [ -f "$(_meta_path "$source")" ] || _err 64 "source is not a den binding: $source"

  [ -d "$target" ] || _err 2 "target is not a directory: $target"
  target="$(cd "$target" && pwd -P)"

  local proj pd
  proj="$(_meta_get "$source" .project)"
  [ -n "$proj" ] && [ "$proj" != "null" ] || _err 65 "source meta missing .project: $source"
  pd="$(_project_dir_for "$proj")"
  [ -d "$pd" ] || _err 65 "project dir missing: $pd"

  local sym_count=0 hard_count=0 skipped=0 missing=0 failed=0
  local entries
  entries="$(jq -c '.symlinks // [] | .[]' "$(_meta_path "$source")")" || \
    _err 65 "cannot read .symlinks from $(_meta_path "$source")"

  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local rel kind src dst
    rel="$(printf '%s' "$entry" | jq -r '.target // empty')"
    kind="$(printf '%s' "$entry" | jq -r '.kind // "symlink"')"
    [ -n "$rel" ] || continue

    src="$pd/files/$rel"
    dst="$target/$rel"

    if [ ! -e "$src" ]; then
      _warn "source missing for $rel; skipping"
      missing=$((missing+1))
      continue
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      skipped=$((skipped+1))
      continue
    fi

    mkdir -p "$(dirname "$dst")"
    if _link_for_kind "$kind" "$src" "$dst" 2>/dev/null; then
      case "$kind" in
        hardlink) hard_count=$((hard_count+1)) ;;
        *)        sym_count=$((sym_count+1)) ;;
      esac
    else
      _warn "failed to $kind $rel into $target"
      failed=$((failed+1))
    fi
  done <<EOF
$entries
EOF

  printf 'den replicate: %d linked (%d symlinks, %d hardlinks), %d skipped' \
    "$((sym_count + hard_count))" "$sym_count" "$hard_count" "$skipped"
  [ "$missing" -gt 0 ] && printf ', %d missing-source' "$missing"
  [ "$failed"  -gt 0 ] && printf ', %d failed'        "$failed"
  printf '\n'

  if [ "$hard_count" -gt 0 ]; then
    _warn "$hard_count hardlinked file(s) share state with source; edits will affect every worktree pointing at the same project file"
  fi

  [ "$failed" -eq 0 ]
}
