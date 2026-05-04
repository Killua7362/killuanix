#!/usr/bin/env bash
# Session dispatcher run by greetd on every login.
#
# `.next-session` is a one-shot override: if it exists, its content names the
# session to launch and the file is deleted afterward (so reboots return to
# DEFAULT_SESSION).
#
# Inputs (env vars set by the nix wrapper in ../default.nix):
#   DEFAULT_SESSION  — "gamescope" | "plasma" | "hyprland"
#   GAMESCOPE_BIN    — abs path to start-gamescope-session
#   PLASMA_BIN       — abs path to startplasma-wayland
#   UWSM_BIN         — abs path to uwsm

# Clean up leftover state from any previous session
systemctl --user reset-failed 2>/dev/null || true
systemctl --user stop gamescope-session.target 2>/dev/null || true

# Clear environment variables from previous desktop sessions
unset QT_QPA_PLATFORM XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP

# One-shot override takes priority
session="$DEFAULT_SESSION"
if [ -f "$HOME/.next-session" ]; then
  session=$(cat "$HOME/.next-session")
  rm -f "$HOME/.next-session"
fi

case "$session" in
  plasma)
    export XDG_CURRENT_DESKTOP=KDE
    export XDG_SESSION_DESKTOP=plasma
    export XDG_SESSION_TYPE=wayland
    exec "$PLASMA_BIN"
    ;;
  hyprland)
    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland
    export XDG_DATA_DIRS="/run/current-system/sw/share:${XDG_DATA_DIRS:-}"
    exec "$UWSM_BIN" start hyprland-uwsm.desktop
    ;;
esac

# Fallback: gamescope
exec "$GAMESCOPE_BIN"
