#!/usr/bin/env bash
# Override of jovian-stubs' steamos-session-select.
# Steam calls this binary when the user clicks "Switch to Desktop".
#
# Writes a one-shot session name to ~/.next-session, then exits the gamescope
# session — greetd reruns the dispatcher which picks up the override.
#
# Inputs:
#   DESKTOP_SESSION  — session name to switch to ("plasma" | "hyprland")

case "$1" in
  gamescope)
    rm -f "$HOME/.next-session"
    ;;
  *)
    echo "$DESKTOP_SESSION" > "$HOME/.next-session"
    ;;
esac
sync
systemctl --user stop gamescope-session.target 2>/dev/null || true
