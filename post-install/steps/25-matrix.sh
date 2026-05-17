#!/usr/bin/env bash
# Matrix — Synapse + 4 mautrix bridges + Element Web. autoStart=false, so we
# bring the stack up, register the local user, and walk through per-bridge
# authentication.

run() {
  local synapse_url="http://localhost:8008"
  local element_url="http://localhost:8009"

  log "verifying sops keys for matrix exist (read-only)"
  if has_cmd sops; then
    local missing=()
    local needed=(
      matrix_postgres_password
      matrix_synapse_db_password
      matrix_synapse_registration_secret
      matrix_bridge_telegram_db_password
      matrix_bridge_telegram_as_token
      matrix_bridge_telegram_hs_token
      matrix_bridge_telegram_pickle_key
      matrix_bridge_telegram_api_id
      matrix_bridge_telegram_api_hash
      matrix_bridge_whatsapp_db_password
      matrix_bridge_whatsapp_as_token
      matrix_bridge_whatsapp_hs_token
      matrix_bridge_whatsapp_pickle_key
      matrix_bridge_meta_instagram_db_password
      matrix_bridge_meta_instagram_as_token
      matrix_bridge_meta_instagram_hs_token
      matrix_bridge_meta_instagram_pickle_key
      matrix_bridge_meta_messenger_db_password
      matrix_bridge_meta_messenger_as_token
      matrix_bridge_meta_messenger_hs_token
      matrix_bridge_meta_messenger_pickle_key
    )
    local decrypted
    decrypted="$(sops -d "$REPO_ROOT/secrets/personal.yaml" 2>/dev/null)" || {
      err "sops -d failed — fix age key first (step 01-sops-verify)"
      return 1
    }
    local k
    for k in "${needed[@]}"; do
      if ! printf '%s\n' "$decrypted" | grep -q "^${k}:"; then
        missing+=("$k")
      fi
    done
    if (( ${#missing[@]} > 0 )); then
      err "sops/personal.yaml missing ${#missing[@]} matrix keys:"
      printf '    - %s\n' "${missing[@]}" >&2
      hint "edit with: sops $REPO_ROOT/secrets/personal.yaml"
      hint "generate tokens: openssl rand -hex 32"
      hint "telegram api: https://my.telegram.org → API development tools"
      return 1
    fi
    ok "all 21 matrix sops keys present"
  else
    warn "sops not on PATH — skipping key verification"
  fi

  log "starting matrix stack (autoStart=false, so explicit start needed)"
  if dry "systemctl start synapse element-web mautrix-*"; then :; else
    sudo systemctl start synapse \
      element-web \
      mautrix-telegram \
      mautrix-whatsapp \
      mautrix-meta-instagram \
      mautrix-meta-messenger
  fi

  log "waiting for synapse client-server endpoint"
  local i
  for i in $(seq 1 30); do
    if has_cmd curl && curl -sf -o /dev/null --max-time 2 "$synapse_url/_matrix/client/versions"; then
      ok "synapse up at $synapse_url"
      break
    fi
    sleep 2
    if (( i == 30 )); then
      err "synapse did not come up in 60s"
      hint "journalctl -u synapse -n 60 --no-pager"
      return 1
    fi
  done

  log "checking element-web"
  if has_cmd curl && ! curl -sf -o /dev/null --max-time 3 "$element_url"; then
    warn "$element_url not reachable yet"
    hint "systemctl status element-web"
  else
    ok "element-web up at $element_url"
  fi

  echo
  echo "=== Step 1: register your Matrix account ==="
  echo "Run this once (idempotent — fails harmless if user exists):"
  echo
  echo "  sudo podman exec -it synapse register_new_matrix_user \\"
  echo "      -c /data/homeserver.yaml \\"
  echo "      -c /etc/synapse/overrides.yaml \\"
  echo "      -u akshay \\"
  echo "      -a $synapse_url"
  echo
  confirm "akshay account registered (or already exists)?" || return 1

  if has_cmd xdg-open; then
    dry "xdg-open $element_url" || xdg-open "$element_url" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  echo
  echo "=== Step 2: log in to Element Web ==="
  echo "  - URL:        $element_url"
  echo "  - server:     matrix.killua.local (auto-filled)"
  echo "  - user:       akshay"
  echo "  - password:   whatever you set in Step 1"
  echo
  confirm "logged into Element Web?" || return 1

  echo
  echo "=== Step 3: authenticate each bridge ==="
  echo "Element top-left + → New room (NOT Start chat — forces encryption)."
  echo "Uncheck 'Enable end-to-end encryption'. Then /invite the bot mxid."
  echo "Once bot joins, mark room as management and follow login flow."
  echo
  printf '%s\n' \
    "  Telegram:  @telegrambot:matrix.killua.local" \
    "             !tg set-management-room" \
    "             !tg login → phone number (E.164) → SMS code" \
    "" \
    "  WhatsApp:  @whatsappbot:matrix.killua.local" \
    "             login qr  → scan QR with phone (Linked Devices)" \
    "" \
    "  Instagram: @instagrambot:matrix.killua.local" \
    "             login → follow cookie flow per" \
    "             https://docs.mau.fi/bridges/go/meta/authentication.html" \
    "" \
    "  Messenger: @messengerbot:matrix.killua.local" \
    "             login → same cookie flow but Facebook session"
  echo
  echo "After each bridge logs into its remote service, double-puppet so the"
  echo "bridge can decrypt YOUR messages in encrypted portal rooms:"
  echo
  echo "  Element → Settings → Help & About → Advanced → Access Token (syt_…)"
  echo "  Then in each management room:  login-matrix syt_xxxxxxx"
  echo
  confirm "all bridges you want are logged in (or skip — you can run later)?" || return 1

  echo
  echo "=== Step 4 (optional): tailscale serve for mobile Element X ==="
  echo "Element X requires HTTPS. Tailscale terminates TLS on the tailnet:"
  echo
  echo "  sudo tailscale serve --bg --https=443 http://127.0.0.1:8008"
  echo
  echo "Then point Element X at https://<killua-magicdns>/"
  echo
  confirm "tailscale serve set up (or not needed)?" || true

  ok "matrix stack configured"
  hint "full bootstrap docs: $REPO_ROOT/modules/containers/matrix/CLAUDE.md"
}
