#!/usr/bin/env bash
# claude-kit mcp — dispatcher.
#
# - warm / status / forget : local cache management. Reads the Nix-emitted
#   catalog at $XDG_DATA_HOME/claude-kit/all-mcp-servers.json (built by
#   modules/common/programs/dev/ai/claude.nix); warms each wrapper via a
#   single JSON-RPC `initialize` so the uvx/npx/uv-run runtime resolves and
#   builds its cache, then records the wrapper's current nix-store command
#   path under $XDG_STATE_HOME/mcp-warm/<name>.warmed so we can detect
#   `stale` later (path changed since last warm).
#
# - everything else        : passthrough to `claude mcp …` (add/remove/test/
#   list/etc.). `list` is intentionally NOT remapped — it still shows the
#   real Claude Code MCP-connect view. Use `status` for the cache view.

_mcp_catalog() {
  printf '%s/claude-kit/all-mcp-servers.json\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

_mcp_state_dir() {
  printf '%s/mcp-warm\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

_mcp_require_catalog() {
  local cat
  cat=$(_mcp_catalog)
  if [ ! -f "$cat" ]; then
    echo "claude-kit mcp: catalog not found: $cat" >&2
    echo "                (run scripts/nix_switch first to generate it)" >&2
    exit 1
  fi
}

_mcp_catalog_names() {
  jq -r 'keys[]' "$(_mcp_catalog)"
}

_mcp_catalog_cmd() {
  jq -r --arg n "$1" '.[$n].command // empty' "$(_mcp_catalog)"
}

# echoes: cached | stale | uncached
_mcp_status_of() {
  local name="$1"
  local sf cur stored
  sf="$(_mcp_state_dir)/$name.warmed"
  cur=$(_mcp_catalog_cmd "$name")
  if [ ! -f "$sf" ]; then
    echo uncached
    return
  fi
  stored=$(head -n 1 "$sf" 2>/dev/null || true)
  if [ "$stored" = "$cur" ]; then
    echo cached
  else
    echo stale
  fi
}

_mcp_record_warm() {
  local name="$1" cmd="$2" sd
  sd=$(_mcp_state_dir)
  mkdir -p "$sd"
  printf '%s\n%s\n' "$cmd" "$(date -Iseconds)" >"$sd/$name.warmed"
}

_mcp_status_cmd() {
  _mcp_require_catalog
  local filter="${1:-all}"
  case "$filter" in
    all | cached | uncached | stale) ;;
    *)
      echo "claude-kit mcp status: unknown filter '$filter' (want: cached|uncached|stale|all)" >&2
      return 2
      ;;
  esac

  printf '%-26s %-9s %s\n' "NAME" "STATUS" "LAST WARMED"
  printf '%-26s %-9s %s\n' "----" "------" "-----------"

  local name st last sf color
  while IFS= read -r name; do
    st=$(_mcp_status_of "$name")
    if [ "$filter" != "all" ] && [ "$filter" != "$st" ]; then
      continue
    fi
    sf="$(_mcp_state_dir)/$name.warmed"
    if [ -f "$sf" ]; then
      last=$(sed -n '2p' "$sf" 2>/dev/null || true)
      [ -z "$last" ] && last="-"
    else
      last="-"
    fi
    case "$st" in
      cached) color=$'\033[32m' ;;
      stale) color=$'\033[33m' ;;
      uncached) color=$'\033[31m' ;;
      *) color="" ;;
    esac
    printf "%-26s %s%-9s\033[0m %s\n" "$name" "$color" "$st" "$last"
  done < <(_mcp_catalog_names)
}

_mcp_warm_one() {
  local name="$1"
  local cmd
  cmd=$(_mcp_catalog_cmd "$name")
  if [ -z "$cmd" ]; then
    printf '\033[31m[!]\033[0m %s: not in catalog\n' "$name" >&2
    return 1
  fi

  local timeout_s="${MCP_WARM_TIMEOUT:-600}"
  local init_req='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"claude-kit-mcp-warm","version":"1"}}}'

  printf '\033[36m==>\033[0m warming %s\n' "$name"
  printf '    command: %s\n' "$cmd"

  local -a args=()
  while IFS= read -r a; do args+=("$a"); done < \
    <(jq -r --arg n "$name" '.[$n].args // [] | .[]' "$(_mcp_catalog)")

  local start now rc=0
  start=$(date +%s)

  set +e
  (
    while IFS='=' read -r k v; do
      [ -n "$k" ] && export "$k=$v"
    done < <(jq -r --arg n "$name" \
      '.[$n].env // {} | to_entries[] | "\(.key)=\(.value)"' \
      "$(_mcp_catalog)")
    (
      printf '%s\n' "$init_req"
      sleep "$timeout_s"
    ) |
      timeout --foreground "$timeout_s" "$cmd" "${args[@]}" |
      head -n 1 >/dev/null
    exit "${PIPESTATUS[1]}"
  )
  rc=$?
  set -e

  now=$(date +%s)
  if [ "$rc" -eq 0 ]; then
    _mcp_record_warm "$name" "$cmd"
    printf '    \033[32m[ok]\033[0m %ds (recorded)\n' "$((now - start))"
  else
    printf '    \033[33m[warn]\033[0m exit %d after %ds (not recorded)\n' "$rc" "$((now - start))"
  fi
}

_mcp_warm_cmd() {
  _mcp_require_catalog
  local -a names=()
  case "${1:-}" in
    "" | --all)
      mapfile -t names < <(_mcp_catalog_names)
      ;;
    --uncached)
      local n st
      while IFS= read -r n; do
        st=$(_mcp_status_of "$n")
        if [ "$st" != "cached" ]; then
          names+=("$n")
        fi
      done < <(_mcp_catalog_names)
      if [ "${#names[@]}" -eq 0 ]; then
        echo "all servers already cached"
        return 0
      fi
      ;;
    --*)
      echo "claude-kit mcp warm: unknown flag '$1'" >&2
      return 2
      ;;
    *)
      names=("$@")
      ;;
  esac

  for n in "${names[@]}"; do
    _mcp_warm_one "$n"
  done
  # shellcheck disable=SC2016
  printf '\n\033[32mdone\033[0m -- caches under $XDG_CACHE_HOME/mcp-{npx,uvx,kindly,...}\n'
}

_mcp_forget_cmd() {
  local sd
  sd=$(_mcp_state_dir)
  case "${1:-}" in
    "")
      echo "claude-kit mcp forget: requires a name or --all" >&2
      return 2
      ;;
    --all)
      rm -rf "$sd"
      echo "forgot all warm state at $sd"
      ;;
    *)
      for n in "$@"; do rm -f "$sd/$n.warmed"; done
      echo "forgot warm state for: $*"
      ;;
  esac
}

_mcp_help() {
  cat <<'EOF'
claude-kit mcp — manage MCP servers + local cache.

Local cache (reads Nix-emitted catalog at $XDG_DATA_HOME/claude-kit/all-mcp-servers.json)
  status [cached|uncached|stale|all]
                            Per-server cache status. Default: all.
                            (Servers marked `stale` were warmed against an
                            older wrapper path — URL / runtime has bumped.)
  warm                      Warm every server in the catalog.
  warm --uncached           Warm only uncached + stale servers.
  warm <name> [...]         Warm specific server(s).
  forget <name> [...]       Drop recorded warm state for those servers.
  forget --all              Wipe the warm state dir.

Pass-through to `claude mcp …` (Claude Code's own view)
  list                      Connect state for the current project's MCP servers.
  add <name> <command> [args…]
  remove <name>
  test <name>

Env:
  MCP_WARM_TIMEOUT=<sec>    per-server initialize timeout (default 600).
EOF
}

cmd_mcp() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    -h | --help | help) _mcp_help ;;
    status) _mcp_status_cmd "$@" ;;
    warm) _mcp_warm_cmd "$@" ;;
    forget) _mcp_forget_cmd "$@" ;;
    "") exec claude mcp ;;
    *) exec claude mcp "$sub" "$@" ;;
  esac
}
