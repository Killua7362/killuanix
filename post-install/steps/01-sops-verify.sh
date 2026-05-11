#!/usr/bin/env bash
# Verify sops can decrypt secrets/personal.yaml with the configured age key.
# Read-only smoke test — never writes, never deletes.

run() {
  local secrets_file="$REPO_ROOT/secrets/personal.yaml"

  if ! has_cmd sops; then
    err "sops not on PATH — install via nix run nixpkgs#sops or apply the flake first"
    return 1
  fi

  if [[ ! -f "$secrets_file" ]]; then
    err "missing $secrets_file"
    return 1
  fi

  local key_file="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
  if [[ ! -s "$key_file" ]]; then
    err "no age key at $key_file — run ./run.sh do 00-age-key first"
    return 1
  fi

  log "decrypting $secrets_file (read-only)"
  if dry "sops -d $secrets_file >/dev/null"; then
    return 0
  fi

  if SOPS_AGE_KEY_FILE="$key_file" sops -d "$secrets_file" >/dev/null 2>&1; then
    ok "sops decrypts cleanly"
    return 0
  fi

  err "sops failed to decrypt — re-run with verbose:"
  hint "SOPS_AGE_KEY_FILE=$key_file sops -d $secrets_file"
  return 1
}
