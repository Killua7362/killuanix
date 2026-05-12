#!/usr/bin/env bash
# `claude-kit lazy bundle` — named groups of plugins/MCP/items.
#
# A bundle is a JSON file at <catalog>/bundles/<name>.json with shape:
#   { name, description, plugins: [], mcp: {}, skills: [], agents: [], commands: [] }
#
# `bundle add <name>` merges it into ./.claude/settings.local.json
# (plugins), ./.mcp.json (mcp), and symlinks skills/agents/commands.
# State is recorded in ./.claude/.lazy-bundles.json so `bundle rm`
# reverses precisely what was added (no guessing from bundle file).

_lazy_bundle_ls() {
  local any=0 line c name path desc applied=""
  local statefile; statefile=$(_lazy_bundle_state)
  if [ -f "$statefile" ]; then
    applied=$(jq -r '.bundles // {} | keys[]' "$statefile" 2>/dev/null || true)
  fi
  while read -r line; do
    [ -n "$line" ] || continue
    any=1
    c="${line%% *}"
    name="${line#* }"
    path="$LAZY_DIR/$c/bundles/$name.json"
    desc=$(jq -r '.description // ""' "$path" 2>/dev/null)
    local mark=" "
    if printf '%s\n' "$applied" | grep -qx "$c/$name"; then mark="*"; fi
    printf '%s %-12s / %-20s  %s\n' "$mark" "$c" "$name" "$desc"
  done < <(_lazy_bundle_files)
  [ "$any" = 1 ] || echo "(no bundles in $LAZY_DIR/*/bundles/)"
  if [ -n "$applied" ]; then echo "  (* = currently applied to $PWD)"; fi
  return 0
}

_lazy_bundle_show() {
  local target="${1:-}"
  [ -n "$target" ] || die "usage: claude-kit lazy bundle show <name>"
  local match; match=$(_lazy_bundle_resolve "$target")
  local n; n=$(printf '%s' "$match" | grep -c . 2>/dev/null || true)
  [ "$n" = 1 ] || die "$([ "$n" = 0 ] && echo not found || echo ambiguous): $target"
  local path; path=$(printf '%s' "$match" | head -1 | awk '{print $2}')
  if [ -t 1 ]; then jq '.' "$path" | bat --style=plain --language=json --paging=auto
  else jq '.' "$path"; fi
}

_lazy_bundle_add() {
  local target="${1:-}"
  [ -n "$target" ] || die "usage: claude-kit lazy bundle add <name>"
  local match; match=$(_lazy_bundle_resolve "$target")
  local n; n=$(printf '%s' "$match" | grep -c . 2>/dev/null || true)
  if [ "$n" = 0 ] || [ -z "$match" ]; then die "bundle not found: $target"; fi
  if [ "$n" -gt 1 ]; then
    echo "lazy: ambiguous bundle name; pick one:" >&2
    printf '%s' "$match" | awk '{print "  " $1 "/" }' >&2
    die "use <catalog>/<name> to disambiguate"
  fi
  local catalog bundle_path
  catalog=$(printf '%s' "$match" | head -1 | awk '{print $1}')
  bundle_path=$(printf '%s' "$match" | head -1 | awk '{print $2}')
  local bundle_name; bundle_name=$(basename "$bundle_path" .json)
  local key="$catalog/$bundle_name"

  local pdir="$PWD/.claude"
  mkdir -p "$pdir"
  local statefile; statefile=$(_lazy_bundle_state)
  [ -f "$statefile" ] || echo '{"bundles": {}}' > "$statefile"

  if jq -e --arg k "$key" '.bundles[$k]' "$statefile" >/dev/null 2>&1; then
    die "bundle already applied: $key (rm it first)"
  fi

  local plugins mcp_keys skills agents commands tmp
  plugins=$(jq -c '.plugins // []' "$bundle_path")
  mcp_keys=$(jq -c '(.mcp // {}) | keys' "$bundle_path")
  skills=$(jq -c '.skills // []' "$bundle_path")
  agents=$(jq -c '.agents // []' "$bundle_path")
  commands=$(jq -c '.commands // []' "$bundle_path")

  # Declarative path: claude-kit.nix exists upward — route every entry
  # through _project_edit_list and then a single project sync.
  local cfg mode="imperative"
  if cfg=$(_lazy_find_project_config); then
    mode="declarative"
    _project_load_sync
    local list_key list_var item rc
    for list_key in plugins skills agents commands; do
      case "$list_key" in
        plugins)  list_var="$plugins" ;;
        skills)   list_var="$skills" ;;
        agents)   list_var="$agents" ;;
        commands) list_var="$commands" ;;
      esac
      while IFS= read -r item; do
        [ -n "$item" ] || continue
        rc=0
        _project_edit_list "$cfg" add "$list_key" "$item" || rc=$?
        case "$rc" in
          0|4) ;;   # added or already present
          *) die "claude-kit.nix edit failed for $list_key/$item (rc=$rc)" ;;
        esac
      done < <(echo "$list_var" | jq -r '.[]')
    done
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      rc=0
      _project_edit_list "$cfg" add mcp "$item" || rc=$?
      case "$rc" in
        0|4) ;;
        *) die "claude-kit.nix edit failed for mcp/$item (rc=$rc)" ;;
      esac
    done < <(echo "$mcp_keys" | jq -r '.[]')

    # One sync materializes everything (.claude/, settings.local.json, .mcp.json).
    _project_sync --quiet
  else
    # Imperative legacy path — write directly into ./.claude/.
    local sjson="$pdir/settings.local.json"
    [ -f "$sjson" ] || echo '{}' > "$sjson"
    tmp=$(mktemp)
    jq --argjson p "$plugins" '
      .enabledPlugins = ((.enabledPlugins // {}) +
        ($p | map({(.): true}) | add // {}))
    ' "$sjson" > "$tmp" && mv "$tmp" "$sjson"

    local mcpfile="$PWD/.mcp.json"
    local has_mcp; has_mcp=$(jq -r '(.mcp // {}) | length' "$bundle_path")
    if [ "$has_mcp" -gt 0 ]; then
      [ -f "$mcpfile" ] || echo '{"mcpServers": {}}' > "$mcpfile"
      tmp=$(mktemp)
      jq --slurpfile b <(jq '.mcp' "$bundle_path") '
        .mcpServers = ((.mcpServers // {}) + $b[0])
      ' "$mcpfile" > "$tmp" && mv "$tmp" "$mcpfile"
    fi

    source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/add.sh"
    local item
    for item in $(echo "$skills"   | jq -r '.[]'); do _lazy_apply_one skills   "$item" || true; done
    for item in $(echo "$agents"   | jq -r '.[]'); do _lazy_apply_one agents   "$item" || true; done
    for item in $(echo "$commands" | jq -r '.[]'); do _lazy_apply_one commands "$item" || true; done
  fi

  # Record state — same shape regardless of mode, plus a `mode` marker
  # so rm knows how to reverse. mcp_keys remains the list of stanza
  # names because that's what we need to remove on rm.
  tmp=$(mktemp)
  jq --arg k "$key" \
     --arg mode "$mode" \
     --argjson plugins "$plugins" \
     --argjson mcp_keys "$mcp_keys" \
     --argjson skills "$skills" \
     --argjson agents "$agents" \
     --argjson commands "$commands" \
     '.bundles[$k] = {
       mode: $mode,
       plugins: $plugins,
       mcp_keys: $mcp_keys,
       skills: $skills,
       agents: $agents,
       commands: $commands
     }' "$statefile" > "$tmp" && mv "$tmp" "$statefile"

  echo "applied bundle: $key ($mode)"
  local pcount mcount
  pcount=$(echo "$plugins" | jq -r 'length')
  mcount=$(echo "$mcp_keys" | jq -r 'length')
  echo "  plugins:  $pcount"
  echo "  mcp:      $mcount"
  echo "  skills:   $(echo "$skills" | jq -r 'length')"
  echo "  agents:   $(echo "$agents" | jq -r 'length')"
  echo "  commands: $(echo "$commands" | jq -r 'length')"
}

_lazy_bundle_rm() {
  local target="${1:-}"
  [ -n "$target" ] || die "usage: claude-kit lazy bundle rm <name>"
  local statefile; statefile=$(_lazy_bundle_state)
  [ -f "$statefile" ] || die "no bundles applied in $PWD"

  local key
  if jq -e --arg k "$target" '.bundles[$k]' "$statefile" >/dev/null 2>&1; then
    key="$target"
  else
    # Try to resolve <name> to <catalog>/<name>
    local matches; matches=$(jq -r --arg n "$target" \
      '.bundles | keys[] | select(endswith("/" + $n))' "$statefile")
    local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
    [ "$n" = 1 ] || die "$([ "$n" = 0 ] && echo not applied || echo ambiguous): $target"
    key=$(printf '%s' "$matches" | head -1)
  fi

  local pdir="$PWD/.claude"
  local entry; entry=$(jq --arg k "$key" '.bundles[$k]' "$statefile")
  local plugins mcp_keys skills agents commands tmp
  local mode; mode=$(echo "$entry" | jq -r '.mode // "imperative"')
  plugins=$(echo "$entry"  | jq -c '.plugins  // []')
  mcp_keys=$(echo "$entry" | jq -c '.mcp_keys // []')
  skills=$(echo "$entry"   | jq -c '.skills   // []')
  agents=$(echo "$entry"   | jq -c '.agents   // []')
  commands=$(echo "$entry" | jq -c '.commands // []')

  if [ "$mode" = "declarative" ]; then
    local cfg
    if ! cfg=$(_lazy_find_project_config); then
      die "bundle $key was applied declaratively but claude-kit.nix is no longer present — restore the file or remove the entry from $statefile by hand"
    fi
    _project_load_sync
    local list_key list_var item rc
    for list_key in plugins skills agents commands mcp; do
      case "$list_key" in
        plugins)  list_var="$plugins" ;;
        skills)   list_var="$skills" ;;
        agents)   list_var="$agents" ;;
        commands) list_var="$commands" ;;
        mcp)      list_var="$mcp_keys" ;;
      esac
      while IFS= read -r item; do
        [ -n "$item" ] || continue
        rc=0
        _project_edit_list "$cfg" rm "$list_key" "$item" || rc=$?
        case "$rc" in
          0|6) ;;   # removed or already absent — both fine
          *) die "claude-kit.nix edit failed for $list_key/$item (rc=$rc)" ;;
        esac
      done < <(echo "$list_var" | jq -r '.[]')
    done
    _project_sync --quiet
  else
    # Imperative legacy reversal.
    local sjson="$pdir/settings.local.json"
    if [ -f "$sjson" ]; then
      tmp=$(mktemp)
      jq --argjson p "$plugins" '
        .enabledPlugins = ((.enabledPlugins // {}) |
          with_entries(select(.key as $k | ($p | index($k)) | not)))
      ' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
    fi

    local mcpfile="$PWD/.mcp.json"
    if [ -f "$mcpfile" ]; then
      tmp=$(mktemp)
      jq --argjson k "$mcp_keys" '
        .mcpServers = ((.mcpServers // {}) |
          with_entries(select(.key as $kk | ($k | index($kk)) | not)))
      ' "$mcpfile" > "$tmp" && mv "$tmp" "$mcpfile"
    fi

    local item
    for item in $(echo "$skills"   | jq -r '.[]'); do rm -f "$pdir/skills/$item" 2>/dev/null || true; done
    for item in $(echo "$agents"   | jq -r '.[]'); do rm -f "$pdir/agents/$item.md" 2>/dev/null || true; done
    for item in $(echo "$commands" | jq -r '.[]'); do rm -f "$pdir/commands/$item.md" 2>/dev/null || true; done
  fi

  tmp=$(mktemp)
  jq --arg k "$key" 'del(.bundles[$k])' "$statefile" > "$tmp" && mv "$tmp" "$statefile"
  # Drop the state file entirely if no bundles remain.
  if [ "$(jq '.bundles | length' "$statefile")" = "0" ]; then rm -f "$statefile"; fi

  echo "removed bundle: $key ($mode)"
}

_lazy_bundle_status() {
  local statefile; statefile=$(_lazy_bundle_state)
  if [ ! -f "$statefile" ]; then
    echo "(no bundles applied in $PWD)"; return 0
  fi
  echo "applied bundles in $PWD:"
  jq -r '.bundles | to_entries[] |
    "  \(.key):\n    plugins=\(.value.plugins | length) mcp=\(.value.mcp_keys | length) skills=\(.value.skills | length) agents=\(.value.agents | length) commands=\(.value.commands | length)"
  ' "$statefile"
}

_lazy_bundle_help() {
  cat <<'EOF'
claude-kit lazy bundle — named groups of plugins/MCP/items.

  ls                              List all bundles (* marks applied to cwd).
  show <name>                     Print bundle contents.
  add <name>                      Apply bundle to cwd ./.claude/.
  add <catalog>/<name>            Disambiguate when name is in multiple catalogs.
  rm <name>                       Reverse a previously-added bundle.
  status                          Show which bundles are applied to cwd.

Bundles live at <catalog>/bundles/<name>.json (auto-discovered).
Apply state is tracked in ./.claude/.lazy-bundles.json so rm reverses
precisely what add wrote.
EOF
}

_lazy_bundle() {
  local verb="${1:-help}"
  shift || true
  case "$verb" in
    ls|list)             _lazy_bundle_ls "$@" ;;
    show|cat)            _lazy_bundle_show "$@" ;;
    add|enable|apply)    _lazy_bundle_add "$@" ;;
    rm|remove|disable)   _lazy_bundle_rm "$@" ;;
    status|st)           _lazy_bundle_status ;;
    help|-h|--help|"")   _lazy_bundle_help ;;
    *) die "lazy bundle: unknown verb '$verb' (try: ls show add rm status)" ;;
  esac
}
