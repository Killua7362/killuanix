#!/usr/bin/env bash
# `icloud` — on-demand driver for the icloud-drive-docker container.
#
# Inputs (env vars set by the nix wrapper in default.nix):
#   ICLOUD_EMAIL_FILE  — path to the sops-decrypted Apple ID email
#   ICLOUD_SYNC_DIR    — host-side directory the container syncs into
#
# Runtime PATH is provided by writeShellApplication's runtimeInputs:
# systemd, podman, coreutils.
# shellcheck disable=SC2016
set -euo pipefail

SERVICE=icloud-drive.service
CONTAINER=icloud-drive

wait_ready() {
  # Wait up to 15s for the container to accept exec.
  for _ in $(seq 1 15); do
    if sudo podman exec "$CONTAINER" true 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "error: container $CONTAINER did not become ready" >&2
  return 1
}

ensure_running() {
  if ! systemctl is-active --quiet "$SERVICE"; then
    sudo systemctl start "$SERVICE"
  fi
  wait_ready
}

case "${1:-help}" in
  login)
    echo "Starting container for login..."
    ensure_running
    email=$(sudo cat "$ICLOUD_EMAIL_FILE")
    echo "Logging in as $email — enter Apple ID password, then the 2FA code."
    sudo podman exec -it "$CONTAINER" \
      icloud --username="$email" --session-directory=/config/session_data
    echo
    echo "Login complete. Run 'icloud sync' to start a sync."
    ;;

  sync)
    echo "Starting sync (sync_interval is 1y, so this runs exactly once)."
    echo "Press Ctrl-C once you see the sync finish — the container will be stopped."
    sudo systemctl start "$SERVICE"
    trap 'echo; echo "Stopping container..."; sudo systemctl stop "$SERVICE" >/dev/null 2>&1 || true' EXIT INT TERM
    sudo journalctl -u "$SERVICE" -f --since=now
    ;;

  stop)
    sudo systemctl stop "$SERVICE"
    echo "Stopped."
    ;;

  status)
    systemctl status "$SERVICE" --no-pager --lines=0 || true
    echo
    echo "Sync directory: $ICLOUD_SYNC_DIR"
    ls -la "$ICLOUD_SYNC_DIR" 2>/dev/null || true
    ;;

  help | -h | --help)
    cat <<EOF
icloud — on-demand iCloud Drive + Photos sync

Usage: icloud <command>

  login    Authenticate with Apple ID (one-time; re-run when 2FA session
           expires, roughly every 60 days)
  sync     Start one sync pass; tail logs; Ctrl-C to stop when done
  stop     Stop the sync container
  status   Show service status + sync directory contents
  help     Show this help

Files land in: $ICLOUD_SYNC_DIR
EOF
    ;;

  *)
    echo "unknown command: $1" >&2
    echo "run 'icloud help' for usage" >&2
    exit 2
    ;;
esac
