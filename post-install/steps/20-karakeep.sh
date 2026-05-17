#!/usr/bin/env bash
# Karakeep — bookmark/read-later app. autoStart=false (along with its meili
# sidecar), so we start the stack, wait for it, and let karakeep-bootstrap
# auto-seed the admin from sops. If bootstrap was disabled or failed, fall
# back to a manual-signup prompt.

run() {
  local url="http://localhost:9090"

  log "starting karakeep + meilisearch"
  if dry "systemctl start karakeep karakeep-meili"; then :; else
    sudo systemctl start karakeep-meili karakeep
  fi

  log "waiting for $url"
  local i ok_flag=0
  for i in $(seq 1 30); do
    if has_cmd curl && curl -sf -o /dev/null --max-time 2 "$url"; then
      ok_flag=1
      break
    fi
    sleep 2
  done
  if (( ok_flag == 0 )); then
    warn "$url not reachable after 60s"
    hint "systemctl status karakeep karakeep-meili"
    hint "journalctl -u karakeep -n 60 --no-pager"
    return 1
  fi
  ok "karakeep up at $url"

  # Bootstrap is wantedBy=multi-user.target so it normally fires on boot, but
  # if karakeep was just started manually it may not have run yet — kick it.
  log "running karakeep-bootstrap (idempotent, sentinel-gated)"
  if dry "systemctl start karakeep-bootstrap"; then :; else
    sudo systemctl start karakeep-bootstrap || true
  fi

  if sudo test -f /var/lib/karakeep/.admin-seeded; then
    ok "admin seeded from sops (karakeep_admin_email / karakeep_admin_password)"
    hint "decrypt password: sops -d $REPO_ROOT/secrets/personal.yaml | grep karakeep_admin"
  else
    warn "bootstrap did not mark sentinel — admin signup may have failed"
    hint "check: sudo journalctl -u karakeep-bootstrap -n 30 --no-pager"
    echo
    echo "Manual fallback: open $url and sign up — first account becomes admin."
  fi

  if has_cmd xdg-open; then
    dry "xdg-open $url" || xdg-open "$url" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  echo
  echo "In the karakeep UI:"
  echo "  1. Log in with the sops admin credentials (or sign up if bootstrap failed)"
  echo "  2. (recommended) Admin Settings → disable signups now that admin exists"
  echo "  3. Settings → API Keys → create TWO tokens:"
  echo "       - one for the browser extension (paste into the extension)"
  echo "       - one for karakeep-import.service (save in sops)"
  echo "  4. Install the Karakeep browser extension from AMO and paste the token"
  echo
  echo "Then save the second API key into sops as karakeep_admin_api_key:"
  echo
  echo "    sops $REPO_ROOT/secrets/personal.yaml"
  echo "    # add line:  karakeep_admin_api_key: \"ak1_<paste>\""
  echo
  echo "After that, decrypt the bookmark export once + re-run nix_switch so"
  echo "karakeep-import.service can read both secrets and import the HTML."
  echo "It will create a list \"Imported from sops\" and dedupe by URL."
  echo

  confirm "logged in, signups disabled, browser-extension token grabbed, importer api key sopsed?" || return 1
  hint "trigger import now: sudo systemctl start karakeep-import"
  hint "verify: journalctl -u karakeep-import -n 50 --no-pager"
  ok "karakeep configured"
}
