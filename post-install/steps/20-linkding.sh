#!/usr/bin/env bash
# Linkding — admin user is auto-created from the sops-encrypted password.
# What's manual: log in once, generate an API token for the browser extension.

run() {
  local url="http://localhost:9090"

  log "checking $url"
  if has_cmd curl && ! curl -sf -o /dev/null --max-time 3 "$url"; then
    warn "$url not reachable — is the linkding container up?"
    hint "systemctl --user status linkding  (or check podman ps)"
  fi

  log "admin password lives in secrets/personal.yaml under 'linkding_admin_password'"
  hint "decrypt with: sops -d $REPO_ROOT/secrets/personal.yaml | grep linkding_admin"

  if has_cmd xdg-open; then
    dry "xdg-open $url" || xdg-open "$url" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  echo
  echo "In the linkding UI:"
  echo "  1. Log in as 'admin' with the password from sops"
  echo "  2. Settings -> Integrations -> Generate API token"
  echo "  3. Paste the token into the linkding browser extension"
  echo

  confirm "token grabbed and extension configured?" || return 1
  ok "linkding configured"
}
