#!/usr/bin/env bash
# Boeing modernization local-dev infra.
# Drives docker-compose via the Justfile at ~/Documents/Boeing/modernization/.
# `just up` brings up mongo + redis + postgres + UIs under project name 'boeing'.

run() {
  local mod_dir="$HOME/Documents/Boeing/modernization"

  if [[ ! -d "$mod_dir" ]]; then
    err "missing $mod_dir — clone the modernization bare repo + worktrees first"
    hint "see project memory 'project_boeing_worktree_layout.md' for layout"
    return 1
  fi

  if ! has_cmd just; then
    err "just not on PATH — devShell at $mod_dir/flake.nix should provide it (direnv)"
    return 1
  fi

  if ! has_cmd docker && ! has_cmd podman; then
    err "neither docker nor podman found"
    return 1
  fi

  log "running 'just up' in $mod_dir"
  dry "(cd $mod_dir && just up)" || (cd "$mod_dir" && just up) || {
    err "just up failed"
    return 1
  }

  log "smoke-checking container UIs"
  local ok_count=0
  for url in \
    "http://localhost:8181"  `# mongo-express` \
    "http://localhost:8281"  `# redis-commander` \
    ; do
    if has_cmd curl && curl -sf -o /dev/null --max-time 5 "$url"; then
      ok "  $url reachable"
      ok_count=$((ok_count+1))
    else
      warn "  $url not reachable yet"
    fi
  done

  if [[ $ok_count -lt 1 ]]; then
    warn "no UIs reachable — check 'docker ps' / 'podman ps'"
    confirm "mark step done anyway?" || return 1
  fi

  ok "boeing infra up"
}
