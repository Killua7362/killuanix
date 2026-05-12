#!/usr/bin/env bash
# `claude-kit project` — read ./claude-kit.nix and reconcile project
# state (./.claude/skills,agents,commands; settings.local.json; ./.mcp.json).
#
# Schema (pure attrset; see modules/.../den/templates/claude-kit.nix):
#   { envVars = {…}; skills = […]; agents = […]; commands = […];
#     plugins = […]; mcp = […]; }
#
# Wired into direnv from the .envrc den drops on `den new --devshell`.
# Globally-enabled skills/MCP (in ~/.claude/) stay loaded — the lists
# below are purely additive.

_project_help() {
  cat <<'EOF'
claude-kit project — flake-driven project resource sync.

  sync [--dry-run] [--quiet]    Reconcile ./.claude/ + ./.mcp.json against
                                ./claude-kit.nix. Default verb.
  add <type> <name>             Insert <name> into the matching list in
                                ./claude-kit.nix and re-sync.
  rm  <type> <name>             Remove <name> from the matching list in
                                ./claude-kit.nix and re-sync.
                                (<type> ∈ skill|agent|command|plugin|mcp)
  envrc                         Print `export VAR=val` lines for non-empty
                                entries in claude-kit.nix:envVars. Empty
                                entries are skipped so the host env wins.
  show                          Print parsed claude-kit.nix as JSON.
  status                        List items currently managed by this sync.
EOF
}

# Echo the parsed claude-kit.nix as JSON. Exits non-zero (and prints to
# stderr) if no claude-kit.nix is found upward from $PWD, or if eval
# fails. The eval is sandbox-safe (pure attrset, no flake context).
_project_eval() {
  local cfg
  cfg=$(_lazy_find_project_config) || { echo "claude-kit: no claude-kit.nix found above $PWD" >&2; return 1; }
  # --strict forces full evaluation so jq sees concrete values; --json
  # emits the result. nix-instantiate is part of every nix install and
  # doesn't need a flake.
  local out err
  err=$(mktemp); out=$(nix-instantiate --eval --strict --json "$cfg" 2>"$err") || {
    echo "claude-kit: failed to evaluate $cfg" >&2
    sed 's/^/  /' "$err" >&2
    rm -f "$err"; return 1
  }
  rm -f "$err"
  printf '%s' "$out"
}

_project_show() {
  _project_eval | jq '.'
}

_project_envrc() {
  local json; json=$(_project_eval) || return 0   # no-op when missing
  echo "$json" | jq -r '
    (.envVars // {}) | to_entries[]
    | select(.value != "" and .value != null)
    | "export \(.key)=\(.value | @sh)"
  '
}

_project_sync() {
  local dryrun=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n) dryrun=1; shift;;
      --quiet|-q)   quiet=1;  shift;;
      -h|--help)    _project_help; return 0;;
      *) die "project sync: unexpected arg '$1'";;
    esac
  done

  local cfg; cfg=$(_lazy_find_project_config) || return 0   # silent miss
  local json; json=$(_project_eval) || return 0
  # Project root is the directory containing claude-kit.nix — pin
  # $PWD there so all downstream paths (.claude/, .mcp.json, .flake-
  # managed.json) land at the project root regardless of where the
  # user invoked us from.
  cd "$(dirname "$cfg")"

  local pdir; pdir=$(_lazy_project_dir)
  local statefile; statefile=$(_lazy_state_file)
  local prev_state="{}"
  if [ -f "$statefile" ]; then prev_state=$(cat "$statefile"); fi

  local skills agents commands plugins mcp
  skills=$(  echo "$json" | jq -c '.skills   // []')
  agents=$(  echo "$json" | jq -c '.agents   // []')
  commands=$(echo "$json" | jq -c '.commands // []')
  plugins=$( echo "$json" | jq -c '.plugins  // []')
  mcp=$(     echo "$json" | jq -c '.mcp      // []')

  _say() { [ "$quiet" = "1" ] || echo "$1"; }
  _do()  { [ "$dryrun" = "1" ] && echo "would: $*" || eval "$*"; }

  # ---- Resource reconcile (skills/agents/commands) ----
  local type ext kind_dir
  for type in skills agents commands; do
    local list_var
    case "$type" in
      skills)   list_var="$skills";   ext="";     kind_dir="$pdir/skills" ;;
      agents)   list_var="$agents";   ext=".md";  kind_dir="$pdir/agents" ;;
      commands) list_var="$commands"; ext=".md";  kind_dir="$pdir/commands" ;;
    esac

    # Add items in the new list that aren't already symlinked.
    local item
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      local target="$kind_dir/$item$ext"
      if [ -e "$target" ] || [ -L "$target" ]; then continue; fi
      if [ "$dryrun" = "1" ]; then
        _say "would add $type: $item"
      else
        local rc=0
        _lazy_apply_one "$type" "$item" || rc=$?
        case "$rc" in
          0)  _say "+ $type: $item" ;;
          2)  : ;;   # already present (race vs. above test)
          64) _say "  ! $type/$item: not in any catalog (skipped)" ;;
          65) _say "  ! $type/$item: ambiguous (use catalog/type/name in flake)" ;;
        esac
      fi
    done < <(echo "$list_var" | jq -r '.[]')

    # Remove items that were previously synced but are no longer listed.
    # Hand-added symlinks (not in prev_state) are left alone.
    local prev_list; prev_list=$(echo "$prev_state" | jq -r --arg t "$type" '(.[$t] // [])[]' 2>/dev/null || true)
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      if ! echo "$list_var" | jq -e --arg n "$item" 'index($n)' >/dev/null 2>&1; then
        local target="$kind_dir/$item$ext"
        if [ -L "$target" ]; then
          _do "rm -f $(printf %q "$target")"
          _say "- $type: $item"
        fi
      fi
    done <<<"$prev_list"
  done

  # ---- Plugins (settings.local.json) ----
  local sjson="$pdir/settings.local.json"
  local plug
  while IFS= read -r plug; do
    [ -n "$plug" ] || continue
    if [ "$dryrun" = "1" ]; then _say "would enable plugin: $plug"; continue; fi
    _lazy_apply_plugin "$plug"
    _say "+ plugin: $plug"
  done < <(echo "$plugins" | jq -r '.[]')

  # Remove plugins previously synced but no longer listed.
  local prev_plugs; prev_plugs=$(echo "$prev_state" | jq -r '(.plugins // [])[]' 2>/dev/null || true)
  while IFS= read -r plug; do
    [ -n "$plug" ] || continue
    if ! echo "$plugins" | jq -e --arg n "$plug" 'index($n)' >/dev/null 2>&1; then
      if [ -f "$sjson" ]; then
        if [ "$dryrun" = "1" ]; then
          _say "would disable plugin: $plug"
        else
          local tmp; tmp=$(mktemp)
          jq --arg n "$plug" 'del(.enabledPlugins[$n])' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
          _say "- plugin: $plug"
        fi
      fi
    fi
  done <<<"$prev_plugs"

  # ---- MCP servers (./.mcp.json mirrored from ~/.claude.json) ----
  local mcpfile="$PWD/.mcp.json"
  local mcp_name
  while IFS= read -r mcp_name; do
    [ -n "$mcp_name" ] || continue
    local stanza; stanza=$(_lazy_resolve_mcp "$mcp_name" || true)
    if [ -z "$stanza" ]; then
      _say "  ! mcp/$mcp_name: not in ~/.claude.json (skipped)"
      continue
    fi
    if [ "$dryrun" = "1" ]; then _say "would add mcp: $mcp_name"; continue; fi
    [ -f "$mcpfile" ] || echo '{"mcpServers": {}}' > "$mcpfile"
    local tmp; tmp=$(mktemp)
    jq --arg n "$mcp_name" --argjson v "$stanza" '.mcpServers[$n] = $v' "$mcpfile" > "$tmp" && mv "$tmp" "$mcpfile"
    _say "+ mcp: $mcp_name"
  done < <(echo "$mcp" | jq -r '.[]')

  local prev_mcp; prev_mcp=$(echo "$prev_state" | jq -r '(.mcp // [])[]' 2>/dev/null || true)
  while IFS= read -r mcp_name; do
    [ -n "$mcp_name" ] || continue
    if ! echo "$mcp" | jq -e --arg n "$mcp_name" 'index($n)' >/dev/null 2>&1; then
      if [ -f "$mcpfile" ]; then
        if [ "$dryrun" = "1" ]; then
          _say "would remove mcp: $mcp_name"
        else
          local tmp; tmp=$(mktemp)
          jq --arg n "$mcp_name" 'del(.mcpServers[$n])' "$mcpfile" > "$tmp" && mv "$tmp" "$mcpfile"
          _say "- mcp: $mcp_name"
        fi
      fi
    fi
  done <<<"$prev_mcp"

  # ---- Write state ----
  if [ "$dryrun" != "1" ]; then
    mkdir -p "$pdir"
    local tmp; tmp=$(mktemp)
    jq -n \
      --argjson s "$skills" \
      --argjson a "$agents" \
      --argjson c "$commands" \
      --argjson p "$plugins" \
      --argjson m "$mcp" \
      '{skills: $s, agents: $a, commands: $c, plugins: $p, mcp: $m}' > "$tmp"
    mv "$tmp" "$statefile"
  fi
}

# _project_mutate <add|rm> <type> <name>
# Public wrapper around _project_edit_list — validates args, locates
# claude-kit.nix, edits in place, then runs project sync.
_project_mutate() {
  local mode="$1" type="$2" name="$3"
  case "$mode" in add|rm) ;; *) die "project $mode: bad mode" ;; esac
  [ -n "$type" ] && [ -n "$name" ] || die "usage: claude-kit project $mode <type> <name>"
  local key; key=$(_lazy_type_to_key "$type") || die "unknown type: $type (try skill|agent|command|plugin|mcp)"
  local cfg; cfg=$(_lazy_find_project_config) || die "no claude-kit.nix found above $PWD"
  local rc=0
  _project_edit_list "$cfg" "$mode" "$key" "$name" || rc=$?
  case "$rc" in
    0)
      if [ "$mode" = add ]; then echo "+ $key: $name"; else echo "- $key: $name"; fi
      _project_sync --quiet
      return 0 ;;
    4) echo "already in claude-kit.nix: $key/$name"; return 0 ;;
    6) echo "not in claude-kit.nix: $key/$name"; return 1 ;;
    *) die "claude-kit.nix edit failed (rc=$rc)" ;;
  esac
}

_project_status() {
  local statefile; statefile=$(_lazy_state_file)
  if [ ! -f "$statefile" ]; then
    echo "(no flake-managed state in $PWD)"; return 0
  fi
  jq '.' "$statefile"
}

cmd_project() {
  # Pull in _lazy_apply_one / _lazy_apply_plugin for the resource loop.
  # shellcheck source=lazy/add.sh
  source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/add.sh"
  local verb="${1:-sync}"
  case "$verb" in
    sync|"")          shift; _project_sync "$@" ;;
    add)              shift; _project_mutate add "$@" ;;
    rm|remove)        shift; _project_mutate rm  "$@" ;;
    envrc)            _project_envrc ;;
    show)             _project_show ;;
    status|st)        _project_status ;;
    help|-h|--help)   _project_help ;;
    --dry-run|--quiet|-n|-q) _project_sync "$@" ;;   # bare flags → sync
    *) die "project: unknown verb '$verb' (try: sync add rm envrc show status)" ;;
  esac
}
