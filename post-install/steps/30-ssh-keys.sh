#!/usr/bin/env bash
# SSH key bootstrap. Same safety rules as the age key: never overwrite
# existing private keys. Generates a fresh ed25519 key only on a truly
# clean ~/.ssh.

run() {
  local ssh_dir="$HOME/.ssh"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  local key="$ssh_dir/id_ed25519"

  if [[ -s "$key" ]]; then
    ok "existing private key at $key — not touching it"
  else
    echo "No private key at $key. Options:"
    echo "  1) Paste an existing private key (multi-line; Ctrl-D to finish)"
    echo "  2) Generate a new ed25519 keypair on this host"
    echo "  3) Skip"
    read -r -p "choice [1-3]: " choice
    case "$choice" in
      1)
        local tmp; tmp="$(mktemp)"
        cat > "$tmp"
        if [[ ! -s "$tmp" ]]; then
          err "no input"; rm -f "$tmp"; return 1
        fi
        dry "install -m 600 $tmp $key" || install -m 600 "$tmp" "$key"
        rm -f "$tmp"
        ;;
      2)
        local email
        email="${USER}@$(hostname -s)"
        dry "ssh-keygen -t ed25519 -C $email -f $key -N ''" \
          || ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
        ;;
      *)
        log "skipped"; return 1
        ;;
    esac
  fi

  if [[ -s "${key}.pub" ]]; then
    log "public key:"
    cat "${key}.pub"
  fi

  if has_cmd ssh-add; then
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
      dry "ssh-add $key" || ssh-add "$key" 2>/dev/null || true
    else
      hint "no SSH_AUTH_SOCK — start an agent (e.g., enable services.ssh-agent or run 'eval \$(ssh-agent)')"
    fi
  fi

  echo
  hint "add the public key above to: GitHub, GitLab, your own servers (~/.ssh/authorized_keys)"
  confirm "public key registered everywhere needed?" || return 1
  ok "ssh keys configured"
}
