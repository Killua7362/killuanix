#!/usr/bin/env bash
# Bootstrap the sops age key.
#
# The flake's sops-nix integration reads from $SOPS_AGE_KEY_FILE if set,
# otherwise from ~/.config/sops/age/keys.txt. Without this key, every
# sops-decrypted secret in the flake fails — git identities, container
# secrets, linkding admin password, etc.
#
# Source options (in order of preference):
#   1. Convert ssh-ed25519 private key from Bitwarden via ssh-to-age
#      (the canonical path on this flake — sops keys are stored as ssh keys
#      in Bitwarden and converted on demand). Calls
#      post-install/convert-ssh-to-age.sh, which self-bootstraps ssh-to-age
#      via `nix shell nixpkgs#ssh-to-age` if not on PATH.
#   2. Paste raw age key contents
#   3. SCP existing age key from another already-configured host
#   4. Read raw age key from a Bitwarden note (requires bw unlocked)
#
# Safety: refuses to overwrite an existing non-empty key file unless
# FORCE=1 is set, and even then prints the existing fingerprint and
# prompts for confirmation. The live key is never deleted by this
# script.

run() {
  local target="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
  local target_dir
  target_dir="$(dirname "$target")"

  log "target: $target"
  log "(override with SOPS_AGE_KEY_FILE=/tmp/foo for testing)"

  if [[ -s "$target" ]]; then
    warn "key file already exists and is non-empty"
    if has_cmd age-keygen; then
      local fp
      fp="$(grep -m1 '^# public key:' "$target" 2>/dev/null || true)"
      [[ -n "$fp" ]] && hint "existing $fp"
    fi
    if [[ "${FORCE:-0}" != "1" ]]; then
      ok "leaving existing key in place — set FORCE=1 to overwrite"
      return 0
    fi
    confirm "OVERWRITE existing key at $target?" || { log "aborted"; return 1; }
  fi

  dry "mkdir -p $target_dir && chmod 700 $target_dir" || {
    mkdir -p "$target_dir"
    chmod 700 "$target_dir"
  }

  echo
  echo "Pick a source:"
  echo "  1) Convert an OpenSSH ed25519 private key (Bitwarden 'killuanix sops ssh' workflow)"
  echo "  2) Paste raw age key contents (multi-line; finish with Ctrl-D)"
  echo "  3) SCP existing age key from another host"
  echo "  4) Read raw age key from Bitwarden note (requires bw unlocked)"
  echo "  5) Abort"
  read -r -p "choice [1-5]: " choice

  case "$choice" in
    1)
      echo
      echo "  Save the ssh-ed25519 private key from Bitwarden into a file first."
      read -r -p "  path to ssh private key (or '-' for stdin): " keypath
      [[ -z "$keypath" ]] && { err "empty path"; return 1; }
      local convert="$REPO_ROOT/post-install/convert-ssh-to-age.sh"
      if [[ ! -x "$convert" ]]; then
        err "missing $convert"
        return 1
      fi
      dry "SOPS_AGE_KEY_FILE=$target $convert $keypath" \
        || SOPS_AGE_KEY_FILE="$target" "$convert" "$keypath" || return 1
      ;;
    2)
      log "paste raw age key, end with Ctrl-D"
      local tmp
      tmp="$(mktemp)"
      cat > "$tmp"
      if [[ ! -s "$tmp" ]]; then
        err "no input received"
        rm -f "$tmp"
        return 1
      fi
      dry "install -m 600 $tmp $target" || install -m 600 "$tmp" "$target"
      rm -f "$tmp"
      ;;
    3)
      read -r -p "user@host: " remote
      [[ -z "$remote" ]] && { err "empty remote"; return 1; }
      dry "scp $remote:~/.config/sops/age/keys.txt $target" \
        || scp "$remote:.config/sops/age/keys.txt" "$target"
      dry "chmod 600 $target" || chmod 600 "$target"
      ;;
    4)
      if ! has_cmd bw; then
        err "bw CLI not found — install bitwarden-cli or use option 1/2"
        return 1
      fi
      if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
        err "bw is not unlocked — run step 10-bitwarden first or: bw unlock"
        return 1
      fi
      dry "bw get notes 'killuanix sops age' > $target" || {
        bw get notes 'killuanix sops age' > "$target"
        chmod 600 "$target"
      }
      ;;
    5|*)
      log "aborted"
      return 1
      ;;
  esac

  if [[ ! -s "$target" ]]; then
    err "key file is empty after write"
    return 1
  fi
  dry "chmod 600 $target" || chmod 600 "$target"

  if has_cmd grep; then
    grep -m1 '^# public key:' "$target" >/dev/null \
      && ok "key written, public key found" \
      || warn "no '# public key:' line in key file — verify it is a valid age key"
  fi

  ok "wrote $target"
  hint "next: ./run.sh do 01-sops-verify"
}
