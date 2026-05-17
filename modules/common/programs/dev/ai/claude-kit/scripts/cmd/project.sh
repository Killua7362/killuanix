#!/usr/bin/env bash
# `claude-kit project` — read ./claude-kit.nix and reconcile project
# state (./.claude/skills,agents,commands; settings.local.json; ./.mcp.json).
#
# Schema (pure attrset; see modules/.../den/templates/claude-kit.nix):
#   { envVars = {…}; skills = […]; agents = […]; commands = […];
#     plugins = […]; mcp = […];
#     # exclusion + permissions + hooks + filesystem narrowing — all
#     # materialize into ./.claude/settings.local.json:
#     excludeMcp = […]; excludePlugins = […];
#     excludeSkills = […]; excludeAgents = […]; excludeCommands = […];
#     allowedTools = […]; deniedTools = […];
#     hooks = null | { Stop = […]; … };
#     restrictToDirs = null | [ "/abs/path" … ]; }
#
# Wired into direnv from the .envrc den drops on `den new --devshell`.
# Globally-enabled skills/MCP (in ~/.claude/) stay loaded — the additive
# lists above (skills/agents/commands/plugins/mcp) layer on top. The
# exclusion + hardening attrs use settings.local.json's precedence over
# settings.json to opt OUT of globals or restrict the project's surface.

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

  local exclude_mcp exclude_plugins exclude_skills exclude_agents exclude_commands
  exclude_mcp=$(     echo "$json" | jq -c '.excludeMcp      // []')
  exclude_plugins=$( echo "$json" | jq -c '.excludePlugins  // []')
  exclude_skills=$(  echo "$json" | jq -c '.excludeSkills   // []')
  exclude_agents=$(  echo "$json" | jq -c '.excludeAgents   // []')
  exclude_commands=$(echo "$json" | jq -c '.excludeCommands // []')

  local allowed_tools denied_tools project_hooks restrict_dirs
  allowed_tools=$( echo "$json" | jq -c '.allowedTools   // []')
  denied_tools=$(  echo "$json" | jq -c '.deniedTools    // []')
  project_hooks=$( echo "$json" | jq -c '.hooks          // null')
  restrict_dirs=$( echo "$json" | jq -c '.restrictToDirs // null')

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

  # restrictToDirs — narrow filesystem MCP `args` to match the project's
  # allowed roots. Only effective if .filesystem ended up in ./.mcp.json
  # (declared via `mcp = [ "filesystem" ]` in claude-kit.nix). Mirrors the
  # claude-launchers.nix behaviour so a project can opt into a sandboxed
  # filesystem MCP scoped to its own tree.
  if [ "$restrict_dirs" != "null" ] && [ -f "$mcpfile" ] \
     && jq -e '.mcpServers.filesystem' "$mcpfile" >/dev/null 2>&1; then
    if [ "$dryrun" = "1" ]; then
      _say "would narrow filesystem MCP args to restrictToDirs"
    else
      local tmp; tmp=$(mktemp)
      jq --argjson dirs "$restrict_dirs" \
        '.mcpServers.filesystem.args = $dirs' "$mcpfile" > "$tmp" && mv "$tmp" "$mcpfile"
      _say "+ mcp/filesystem.args = restrictToDirs"
    fi
  fi

  # ---- settings.local.json: excludes / permissions / hooks / restrictToDirs ----
  #
  # Strategy: revert everything we wrote on the previous run (recorded under
  # prev_state.settingsLocal), then apply the current schema. This way
  # hand-edits to settings.local.json that we didn't author are preserved.
  if [ "$dryrun" != "1" ]; then
    local prev_sl; prev_sl=$(echo "$prev_state" | jq -c '.settingsLocal // {}')
    if [ -f "$sjson" ] && [ "$(echo "$prev_sl" | jq -r 'length')" != "0" ]; then
      local tmp; tmp=$(mktemp)
      jq --argjson prev "$prev_sl" '
        # Strip plugin keys we previously force-disabled.
        (($prev.excludePlugins // []) | reduce .[] as $p (.; del(.enabledPlugins[$p])))
        # Strip allowedTools we previously added.
        | (.permissions.allow //= [])
        | .permissions.allow = (.permissions.allow - ($prev.permissionsAllow // []))
        # Strip deniedTools / excludeMcp-derived / restrictToDirs-derived denies.
        | (.permissions.deny //= [])
        | .permissions.deny = (.permissions.deny - ($prev.permissionsDeny // []))
        # Strip additionalDirectories if we set it last run.
        | if ($prev.additionalDirectoriesSet // false)
            then del(.permissions.additionalDirectories) else . end
        # Strip hooks if we wrote them last run.
        | if ($prev.hooksManaged // false) then del(.hooks) else . end
        # Compact empty containers we may have introduced.
        | if (.permissions.allow == [])              then del(.permissions.allow) else . end
        | if (.permissions.deny  == [])              then del(.permissions.deny)  else . end
        | if (.permissions      // {}) == {}         then del(.permissions)      else . end
        | if (.enabledPlugins   // {}) == {}         then del(.enabledPlugins)   else . end
      ' "$sjson" > "$tmp" && mv "$tmp" "$sjson"
    fi
  fi

  # Compute the new managed-deny set: deniedTools ∪ excludeMcp-as-patterns ∪
  # (if restrictToDirs is set) the sensitive-path baseline.
  local managed_deny
  managed_deny=$(jq -n \
    --argjson d "$denied_tools" \
    --argjson x "$exclude_mcp" \
    --argjson r "$restrict_dirs" \
    --arg home "$HOME" '
      ($d
       + ($x | map("mcp__\(.)__*"))
       + (if $r == null then []
          else [
            "Read(/etc/**)",
            "Read(/var/**)",
            "Read(/root/**)",
            "Read(\($home)/.ssh/**)",
            "Read(\($home)/.gnupg/**)",
            "Read(\($home)/.config/sops/**)",
            "Read(\($home)/.config/age/**)"
          ] end))
      | unique
  ')
  local managed_allow; managed_allow=$(echo "$allowed_tools" | jq 'unique')
  local managed_excl_plugs; managed_excl_plugs=$(echo "$exclude_plugins" | jq 'unique')

  # Apply current schema into settings.local.json.
  local has_apply=0
  if [ "$(echo "$managed_allow" | jq 'length')" != "0" ] \
     || [ "$(echo "$managed_deny" | jq 'length')" != "0" ] \
     || [ "$(echo "$managed_excl_plugs" | jq 'length')" != "0" ] \
     || [ "$restrict_dirs" != "null" ] \
     || [ "$project_hooks" != "null" ]; then
    has_apply=1
  fi

  if [ "$has_apply" = "1" ] && [ "$dryrun" = "1" ]; then
    [ "$(echo "$managed_excl_plugs" | jq 'length')" != "0" ] \
      && _say "would disable plugins: $(echo "$managed_excl_plugs" | jq -r 'join(", ")')"
    [ "$(echo "$managed_allow" | jq 'length')" != "0" ] \
      && _say "would add ${managed_allow} to permissions.allow"
    [ "$(echo "$managed_deny"  | jq 'length')" != "0" ] \
      && _say "would add ${managed_deny} to permissions.deny"
    [ "$restrict_dirs" != "null" ] \
      && _say "would set permissions.additionalDirectories = $restrict_dirs"
    [ "$project_hooks" != "null" ] \
      && _say "would set hooks = $project_hooks"
  elif [ "$has_apply" = "1" ]; then
    [ -f "$sjson" ] || echo '{}' > "$sjson"
    local tmp; tmp=$(mktemp)
    jq --argjson allow "$managed_allow" \
       --argjson deny  "$managed_deny" \
       --argjson xplugs "$managed_excl_plugs" \
       --argjson rdirs "$restrict_dirs" \
       --argjson hooks "$project_hooks" '
      # Force-disable excluded plugins (last wins over any prior true).
      ($xplugs | reduce .[] as $p (.; .enabledPlugins[$p] = false))
      # Append allowedTools / deniedTools (deduped).
      | (if ($allow | length) > 0
           then .permissions.allow = ((.permissions.allow // []) + $allow | unique)
           else . end)
      | (if ($deny | length) > 0
           then .permissions.deny  = ((.permissions.deny  // []) + $deny  | unique)
           else . end)
      # Pin additionalDirectories when restrictToDirs is set.
      | (if $rdirs != null
           then .permissions.additionalDirectories = $rdirs
           else . end)
      # Replace hooks block.
      | (if $hooks != null then .hooks = $hooks else . end)
    ' "$sjson" > "$tmp" && mv "$tmp" "$sjson"

    [ "$(echo "$managed_excl_plugs" | jq 'length')" != "0" ] && _say "+ excluded plugins (disabled): $(echo "$managed_excl_plugs" | jq -r 'join(", ")')"
    [ "$(echo "$managed_allow" | jq 'length')" != "0" ] && _say "+ permissions.allow += $(echo "$managed_allow" | jq -r 'join(", ")')"
    [ "$(echo "$managed_deny"  | jq 'length')" != "0" ] && _say "+ permissions.deny  += $(echo "$managed_deny"  | jq -r 'join(", ")')"
    [ "$restrict_dirs" != "null" ] && _say "+ permissions.additionalDirectories = $(echo "$restrict_dirs" | jq -r 'join(", ")')"
    [ "$project_hooks" != "null" ] && _say "+ hooks (project-scoped) installed"
  fi

  # excludeSkills / excludeAgents / excludeCommands are advisory at the
  # project layer (Claude reads these from ~/.claude/; there's no strict
  # project-level mask). We accept them for symmetry with the launcher
  # schema + record them in state so the show/status output is useful, but
  # do not materialize them here.
  if [ "$(echo "$exclude_skills"   | jq 'length')" != "0" ] \
     || [ "$(echo "$exclude_agents"   | jq 'length')" != "0" ] \
     || [ "$(echo "$exclude_commands" | jq 'length')" != "0" ]; then
    _say "  i excludeSkills/Agents/Commands are advisory (see claude-kit.nix comments)"
  fi

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
      --argjson xs "$exclude_skills" \
      --argjson xa "$exclude_agents" \
      --argjson xc "$exclude_commands" \
      --argjson xp "$managed_excl_plugs" \
      --argjson xm "$exclude_mcp" \
      --argjson pa "$managed_allow" \
      --argjson pd "$managed_deny" \
      --argjson rd "$restrict_dirs" \
      --argjson hk "$project_hooks" '
      {
        skills: $s, agents: $a, commands: $c, plugins: $p, mcp: $m,
        excludeSkills: $xs, excludeAgents: $xa, excludeCommands: $xc,
        excludePlugins: $xp, excludeMcp: $xm,
        allowedTools: $pa, deniedTools: $pd,
        restrictToDirs: $rd, hooks: $hk,
        settingsLocal: {
          excludePlugins: $xp,
          permissionsAllow: $pa,
          permissionsDeny: $pd,
          additionalDirectoriesSet: ($rd != null),
          hooksManaged: ($hk != null)
        }
      }' > "$tmp"
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
