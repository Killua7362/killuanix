#!/usr/bin/env bash
cmd_clean() {
  local all=0
  local keep=50
  while [ $# -gt 0 ]; do
    case "$1" in
      -a|--all) all=1; shift ;;
      -h|--help)
        echo "usage: claude-kit clean [-a|--all]"
        echo "  Keeps the 50 most recent sessions per project; deletes the rest"
        echo "  along with their cached markdown previews. Prompts for 'yes'."
        echo "  -a  apply to every project under ~/.claude/projects/"
        return 0 ;;
      *) die "clean: unknown flag $1" ;;
    esac
  done

  local proj_root="$CLAUDE_DIR/projects"
  local cache_root="$KIT_CACHE/sessions"
  [ -d "$proj_root" ] || die "no $proj_root — has Claude Code been run yet?"

  local projects=()
  if [ "$all" = 1 ]; then
    while IFS= read -r d; do projects+=("$d"); done < <(find "$proj_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  else
    local enc="${PWD//\//-}"
    [ -d "$proj_root/$enc" ] || die "no Claude history for $PWD (try: claude-kit clean --all)"
    projects=("$proj_root/$enc")
  fi
  [ "${#projects[@]}" -gt 0 ] || die "no projects to clean"

  # Build deletion plan: per-project list jsonls sorted by mtime descending
  # and stage everything past `$keep` into a temp file. Stay quiet about
  # projects that have nothing to delete; only show rows for what's about
  # to be cut, after the user confirms there's something to confirm.
  local plan; plan=$(mktemp -t claude-kit-clean-plan.XXXXXX)
  local total=0 affected=0 grand_count=0 p enc count del rows=""

  for p in "${projects[@]}"; do
    enc=$(basename "$p")
    local sorted
    sorted=$(find "$p" -maxdepth 1 -name '*.jsonl' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-)
    count=$(printf '%s' "$sorted" | grep -c '^' 2>/dev/null || echo 0)
    grand_count=$((grand_count + count))
    if [ "$count" -le "$keep" ]; then continue; fi
    del=$((count - keep))
    printf '%s\n' "$sorted" | tail -n +"$((keep + 1))" >> "$plan"
    total=$((total + del))
    affected=$((affected + 1))
    rows+="  $(printf '%-50s  %s session(s), will delete %s, keep %s' "$enc" "$count" "$del" "$keep")"$'\n'
  done

  if [ "$total" -eq 0 ]; then
    rm -f "$plan"
    if [ "$all" = 1 ]; then
      printf 'claude-kit clean: nothing to clean — %s session(s) across %s project(s), all under the %s-session keep threshold\n' \
        "$grand_count" "${#projects[@]}" "$keep" >&2
    else
      printf 'claude-kit clean: nothing to clean — %s session(s) for this project, under the %s-session keep threshold\n' \
        "$grand_count" "$keep" >&2
    fi
    return 0
  fi

  printf '%s' "$rows" >&2
  echo >&2
  printf '%s session(s) across %s project(s) will be permanently deleted.\n' "$total" "$affected" >&2
  printf "Type exactly 'yes' to proceed (anything else aborts): " >&2
  local answer=""
  IFS= read -r answer || answer=""
  if [ "$answer" != "yes" ]; then
    rm -f "$plan"
    echo "aborted (got: ${answer:-<empty>})" >&2
    return 1
  fi

  local deleted=0 jl sid e
  while IFS= read -r jl; do
    [ -n "$jl" ] || continue
    [ -f "$jl" ] || continue
    sid=$(basename "$jl" .jsonl)
    e=$(basename "$(dirname "$jl")")
    rm -f -- "$jl"
    rm -f -- "$cache_root/$e/$sid.md" 2>/dev/null || true
    deleted=$((deleted + 1))
  done < "$plan"
  rm -f "$plan"

  printf 'claude-kit clean: deleted %s session(s)\n' "$deleted" >&2
}
