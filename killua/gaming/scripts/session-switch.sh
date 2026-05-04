#!/usr/bin/env bash
# `session-switch <plasma|hyprland|gaming>` — runtime session switcher.
#
# Writes the desired session into ~/.next-session (or removes it for
# gaming/gamescope) and exits the current session so greetd reruns the
# dispatcher.
#
# Inputs (for help text only):
#   DEFAULT_SESSION  — boot default (configured in default.nix)
#   DESKTOP_SESSION  — "Switch to Desktop" target

usage() {
  echo "Usage: session-switch <plasma|hyprland|gaming>"
  echo ""
  echo "  plasma    - Switch to KDE Plasma desktop"
  echo "  hyprland  - Switch to Hyprland compositor (UWSM)"
  echo "  gaming    - Switch to Steam Game Mode (gamescope)"
  echo ""
  echo "Config (in killua/gaming/default.nix):"
  echo "  defaultSession = \"$DEFAULT_SESSION\"   (boot default)"
  echo "  desktopSession = \"$DESKTOP_SESSION\"   (Switch to Desktop target)"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

exit_session() {
  sync
  case "${XDG_CURRENT_DESKTOP:-}" in
    gamescope)
      systemctl --user stop gamescope-session.target 2>/dev/null || true
      ;;
    Hyprland|hyprland)
      hyprctl dispatch exit 2>/dev/null || true
      ;;
    KDE)
      qdbus org.kde.Shutdown /Shutdown logout 2>/dev/null || \
      loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
      ;;
    *)
      loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
      ;;
  esac
}

case "$1" in
  plasma)
    echo "Switching to Plasma desktop..."
    echo "plasma" > "$HOME/.next-session"
    exit_session
    ;;
  hyprland)
    echo "Switching to Hyprland..."
    echo "hyprland" > "$HOME/.next-session"
    exit_session
    ;;
  gaming|gamescope|steam)
    echo "Switching to Steam Game Mode..."
    rm -f "$HOME/.next-session"
    exit_session
    ;;
  *)
    usage
    ;;
esac
