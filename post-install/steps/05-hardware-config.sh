#!/usr/bin/env bash
# Copy the freshly-generated /etc/nixos/hardware-configuration.nix into
# the matching host directory in this checkout. Required on a fresh
# install before the first nixos-rebuild — the committed
# hardware-configuration.nix is the *previous* host's, not yours.
#
# Host dir is picked from $HOSTNAME_SHORT. The script diffs first and
# refuses to overwrite without confirmation.

run() {
  local src="/etc/nixos/hardware-configuration.nix"
  local host="$HOSTNAME_SHORT"
  local dest="$REPO_ROOT/$host/hardware-configuration.nix"

  if [[ ! -r "$src" ]]; then
    err "no $src on this system — are you on a NixOS host?"
    return 1
  fi

  if [[ ! -d "$REPO_ROOT/$host" ]]; then
    err "no host dir $REPO_ROOT/$host (expected one of: chrollo, killua)"
    hint "fix \$(hostname) or pass HOSTNAME_SHORT=<chrollo|killua>"
    return 1
  fi

  if [[ -f "$dest" ]] && diff -q "$src" "$dest" >/dev/null 2>&1; then
    ok "$dest already matches $src"
    return 0
  fi

  log "diff (current committed file vs freshly generated):"
  diff -u "$dest" "$src" || true
  echo

  confirm "overwrite $dest with $src?" || { log "skipped"; return 1; }

  dry "cp $src $dest" || cp "$src" "$dest"
  ok "wrote $dest"
  hint "review with: git -C $REPO_ROOT diff $host/hardware-configuration.nix"
}
