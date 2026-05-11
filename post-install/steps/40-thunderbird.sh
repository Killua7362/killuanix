#!/usr/bin/env bash
# Thunderbird first-run account wizard. No declarative account config in
# this flake (see modules/common/programs/mail/CLAUDE.md), so this is
# fully manual — script just launches the app and waits.

run() {
  if ! has_cmd thunderbird; then
    err "thunderbird not on PATH"
    return 1
  fi

  dry "thunderbird &" || thunderbird >/dev/null 2>&1 &
  disown 2>/dev/null || true

  echo
  echo "Manual checklist:"
  echo "  1. Add email account via the wizard"
  echo "  2. Verify IMAP/SMTP authentication"
  echo "  3. Confirm bundled add-ons (declared in mail module) are enabled"
  echo

  confirm "account configured and mail syncing?" || return 1
  ok "thunderbird configured"
}
