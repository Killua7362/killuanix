#!/usr/bin/env bash
# killua-only (MSI Claw handheld). Steam login, hhd-ui config, Decky.
# No-op on other hosts.

run() {
  if [[ "$HOSTNAME_SHORT" != "killua" ]]; then
    ok "not killua (host=$HOSTNAME_SHORT) — skipping handheld-only step"
    return 0
  fi

  echo
  echo "Handheld setup checklist:"
  echo "  1. hhd-ui — open and verify TDP / fan / RGB profiles match your preferences"
  echo "  2. Steam — sign in, enable Big Picture / Gamescope autostart if desired"
  echo "  3. Decky Loader — install plugins (PowerTools, etc.) via the in-app store"
  echo "  4. Verify CachyOS kernel + Jovian wiring (see killua/configuration.nix)"
  echo "  5. Test gyro / trackpad bindings in a known-good game"
  echo

  if has_cmd hhd-ui; then
    dry "hhd-ui &" || hhd-ui >/dev/null 2>&1 &
    disown 2>/dev/null || true
  else
    warn "hhd-ui not on PATH"
  fi

  confirm "all five done?" || return 1
  ok "handheld configured"
}
