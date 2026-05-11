#!/usr/bin/env bash
# Log into Bitwarden CLI and unlock the vault for this shell session.
# The desktop app (declarative via firefox/default.nix) handles browser
# unlock separately — this is for `bw` CLI use (e.g., 00-age-key option 3).

run() {
  if ! has_cmd bw; then
    err "bw CLI missing — add it to packages or: nix shell nixpkgs#bitwarden-cli"
    return 1
  fi

  local status
  status="$(bw status 2>/dev/null || echo '{}')"

  if echo "$status" | grep -q '"status":"unauthenticated"'; then
    log "logging in to Bitwarden"
    dry "bw login" || bw login || return 1
    status="$(bw status 2>/dev/null || echo '{}')"
  fi

  if echo "$status" | grep -q '"status":"unlocked"'; then
    ok "bw already unlocked for this session"
    return 0
  fi

  log "unlocking vault — copy the export line below into your shell"
  if dry "bw unlock"; then
    return 0
  fi

  local session
  session="$(bw unlock --raw)" || { err "unlock failed"; return 1; }
  echo
  printf '  %sexport BW_SESSION=%q%s\n' "$C_BOLD" "$session" "$C_RESET"
  echo
  hint "paste that into your shell to use bw in subsequent commands"
  ok "vault unlocked"
}
