#!/usr/bin/env bash
cmd_resume() {
  local all=0 free=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -a|--all)  all=1; shift ;;
      -f|--free) free=1; shift ;;
      -h|--help)
        echo "usage: claude-kit resume [-a|--all] [-f|--free]"
        echo "  -a  pick from sessions across every project"
        echo "  -f  open with your normal yazi config (no restricted UI)"
        return 0 ;;
      *) die "resume: unknown flag $1" ;;
    esac
  done

  local proj_root="$CLAUDE_DIR/projects"
  local cache_root="$KIT_CACHE/sessions"
  [ -d "$proj_root" ] || die "no $proj_root — has Claude Code been run yet?"
  mkdir -p "$cache_root"

  # Scope: current project (default) or all projects (-a). When scoped to
  # the current project and it has no sessions, just say so — don't widen
  # to global automatically; the user can re-run with -a if they want.
  local projects=()
  if [ "$all" = 0 ]; then
    local enc="${PWD//\//-}"
    if [ -d "$proj_root/$enc" ] && [ -n "$(find "$proj_root/$enc" -maxdepth 1 -name '*.jsonl' -print -quit 2>/dev/null)" ]; then
      projects=("$proj_root/$enc")
    else
      echo "claude-kit resume: no sessions for $PWD (use -a/--all to pick from every project)" >&2
      return 0
    fi
  else
    while IFS= read -r d; do
      [ -n "$(find "$d" -maxdepth 1 -name '*.jsonl' -print -quit 2>/dev/null)" ] && projects+=("$d")
    done < <(find "$proj_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi
  [ "${#projects[@]}" -gt 0 ] || die "no Claude sessions found anywhere under $proj_root"

  local view; view=$(mktemp -d -t claude-kit-resume.XXXXXX)

  # First pass: count jsonls that need (re)rendering, so we can show a
  # progress meter only when there's work to do.
  local needs_render=0 p enc jl sid mtime ts md ln_name
  for p in "${projects[@]}"; do
    enc=$(basename "$p")
    while IFS= read -r jl; do
      [ -f "$jl" ] || continue
      sid=$(basename "$jl" .jsonl)
      md="$cache_root/$enc/$sid.md"
      if [ ! -f "$md" ] || [ "$jl" -nt "$md" ]; then
        needs_render=$((needs_render + 1))
      fi
    done < <(find "$p" -maxdepth 1 -name '*.jsonl' 2>/dev/null)
  done
  [ "$needs_render" -gt 0 ] && printf 'claude-kit resume: rendering %s session(s)...\n' "$needs_render" >&2

  local total=0 done_render=0
  for p in "${projects[@]}"; do
    enc=$(basename "$p")
    while IFS= read -r jl; do
      [ -f "$jl" ] || continue
      sid=$(basename "$jl" .jsonl)
      mtime=$(stat -c %Y "$jl" 2>/dev/null || stat -f %m "$jl" 2>/dev/null || echo 0)
      ts=$(date -d "@$mtime" '+%Y-%m-%d_%H%M' 2>/dev/null || date -r "$mtime" '+%Y-%m-%d_%H%M' 2>/dev/null || echo "unknown")
      md="$cache_root/$enc/$sid.md"
      if [ ! -f "$md" ] || [ "$jl" -nt "$md" ]; then
        done_render=$((done_render + 1))
        printf '\r  [%s/%s] %s' "$done_render" "$needs_render" "$sid" >&2
        _render_session "$jl" "$md" "$enc" || printf 'render failed: %s\n' "$sid" >&2
      fi
      if [ "$all" = 1 ]; then
        ln_name="${ts}__${enc}__${sid:0:8}.md"
      else
        ln_name="${ts}__${sid:0:8}.md"
      fi
      ln -sf "$md" "$view/$ln_name"
      total=$((total + 1))
    done < <(find "$p" -maxdepth 1 -name '*.jsonl' 2>/dev/null)
  done
  [ "$needs_render" -gt 0 ] && printf '\r%80s\r' "" >&2  # clear progress line

  [ "$total" -gt 0 ] || die "no sessions to pick from"
  printf 'claude-kit resume: %s session(s) ready in yazi\n' "$total" >&2

  # Restricted-UI mode: hide the parent panel, sort newest-first, and
  # block keys that would navigate out of the view dir. -f/--free skips
  # this and uses the user's normal yazi config.
  local cfg=""
  if [ "$free" = 0 ]; then
    cfg=$(mktemp -d -t claude-kit-yazi-cfg.XXXXXX)
    local src="${YAZI_CONFIG_HOME:-$HOME/.config/yazi}"
    [ -e "$src/theme.toml"   ] && ln -s "$src/theme.toml"   "$cfg/theme.toml"   || true
    [ -e "$src/flavors"      ] && ln -s "$src/flavors"      "$cfg/flavors"      || true
    [ -e "$src/plugins"      ] && ln -s "$src/plugins"      "$cfg/plugins"      || true
    cat > "$cfg/yazi.toml" <<'YAZICFG'
[mgr]
ratio        = [0, 4, 3]
sort_by      = "natural"
sort_sensitive = false
sort_reverse = true
sort_dir_first = false
show_hidden  = false
YAZICFG
    cat > "$cfg/keymap.toml" <<'YAZIKM'
# Block any key that would leave the conversations view.
[[mgr.prepend_keymap]]
on  = "n"
run = "noop"
desc = "blocked: stay in conversations view"

[[mgr.prepend_keymap]]
on  = "<Left>"
run = "noop"

[[mgr.prepend_keymap]]
on  = "<Backspace>"
run = "noop"

[[mgr.prepend_keymap]]
on  = "h"
run = "noop"

[[mgr.prepend_keymap]]
on  = "N"
run = "noop"

[[mgr.prepend_keymap]]
on  = "O"
run = "noop"
YAZIKM
  fi

  local choose; choose=$(mktemp -t claude-kit-resume-pick.XXXXXX)
  if [ -n "$cfg" ]; then
    YAZI_CONFIG_HOME="$cfg" yazi --chooser-file="$choose" "$view" || true
  else
    yazi --chooser-file="$choose" "$view" || true
  fi
  local picked=""
  [ -s "$choose" ] && picked=$(head -n1 "$choose")

  # Resolve the symlink target *before* removing the view dir, otherwise
  # readlink can't follow it.
  local real=""
  if [ -n "$picked" ]; then
    real=$(readlink -f "$picked" 2>/dev/null || echo "$picked")
  fi
  rm -rf "$view" "$choose"
  [ -n "$cfg" ] && rm -rf "$cfg"

  if [ -z "$real" ]; then
    echo "claude-kit resume: no selection (use yazi's 'open' action — your keymap binds it to 'l', not Enter)" >&2
    return 1
  fi
  sid=$(basename "$real" .md)
  local picked_enc; picked_enc=$(basename "$(dirname "$real")")
  local jsonl="$proj_root/$picked_enc/$sid.jsonl"
  [ -f "$jsonl" ] || die "session jsonl missing: $jsonl"

  # Authoritative cwd is in the jsonl (encoded basename isn't reversible).
  local cwd
  cwd=$(jq -rs 'map(select(.cwd))[0].cwd // ""' "$jsonl" 2>/dev/null)
  if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
    die "session cwd not available or no longer exists (was: ${cwd:-unknown})"
  fi

  echo "claude-kit resume: $sid in $cwd" >&2
  cd "$cwd" && exec claude --resume "$sid"
}
