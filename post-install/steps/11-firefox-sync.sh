#!/usr/bin/env bash
# Sign into Firefox Sync (and Bitwarden browser extension master pw).
# Irreducibly manual — the script just opens the right pages and waits.

run() {
  if ! has_cmd firefox; then
    warn "firefox not on PATH — open manually"
  else
    dry "firefox about:preferences#sync &" || firefox 'about:preferences#sync' >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  echo
  echo "Manual checklist:"
  echo "  1. Sign into Firefox Sync (about:preferences#sync)"
  echo "  2. Wait for sync to pull bookmarks, history, extensions"
  echo "  3. Click the Bitwarden extension icon, enter master password"
  echo "  4. Verify autofill works on a known site"
  echo

  confirm "all four done?" || { log "come back when ready"; return 1; }
  ok "firefox configured"
}
