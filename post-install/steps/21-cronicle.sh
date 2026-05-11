#!/usr/bin/env bash
# Cronicle — declarative events bootstrapped by cronicle-bootstrap.service.
# Manual: change the default admin/admin password on first visit.

run() {
  local url="http://localhost:3012"

  log "checking $url"
  if has_cmd curl && ! curl -sf -o /dev/null --max-time 3 "$url"; then
    warn "$url not reachable — cronicle container may be down"
    hint "podman ps | grep cronicle  /  systemctl --user status cronicle"
  fi

  if has_cmd xdg-open; then
    dry "xdg-open $url" || xdg-open "$url" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  echo
  echo "In the cronicle UI:"
  echo "  1. Log in as admin / admin"
  echo "  2. Top-right user menu -> My Account -> change password"
  echo "  3. Schedule -> verify expected events appear and are enabled"
  echo "  4. (optional) trigger one event to confirm execution path"
  echo

  confirm "cronicle reachable, password changed, events visible?" || return 1
  ok "cronicle configured"
}
