#!/usr/bin/env bash
# `return-to-gaming-mode` — desktop entry that exits the current desktop
# session and returns to Steam Game Mode.
#
# Removes the .next-session override (so the dispatcher falls back to its
# default = gamescope), then issues a session-appropriate logout. The
# greetd autologin reruns the dispatcher → gamescope.
#
# Relies on the user session PATH for hyprctl/qdbus/dbus-send/loginctl/uwsm
# (matches behavior of the original writeShellScriptBin).

rm -f "$HOME/.next-session"
case "$XDG_CURRENT_DESKTOP" in
  Hyprland|hyprland)
    uwsm stop
    hyprctl dispatch exit 2>/dev/null || true
    ;;
  KDE)
    qdbus org.kde.Shutdown /Shutdown logout 2>/dev/null || \
    dbus-send --session --type=method_call --dest=org.kde.ksmserver \
      /KSMServer org.kde.KSMServerInterface.logout \
      int32:0 int32:0 int32:0 2>/dev/null || \
    loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
    ;;
  *)
    loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
    ;;
esac
