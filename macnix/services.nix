# macnix system-side services.
#
# Two pieces of declarative-OS plumbing live here:
#
#   - services.aerospace — the only window manager on macnix. The keymap
#     mirrors the Hyprland config in
#     modules/common/programs/desktop/hyprland/keybinds.nix so muscle memory
#     carries between Linux and macOS hosts.
#
#     The leader is `alt`. Combined with system.keyboard.swapLeftCommandAndLeftAlt
#     in settings.nix (which swaps the physical left-Cmd ↔ left-Alt at the
#     OS level), an `alt-…` binding is triggered by the *physical* left-Cmd
#     key — i.e. the same hand position as `Super` on a Linux keyboard.
#     If you ever drop the swap, rewrite all `alt-…` bindings to `cmd-…`.
#
#   - services.karabiner-elements — installs the DriverKit extension and
#     launchd plumbing. The userspace karabiner.json (which actually does
#     the CapsLock ↔ Escape swap) is owned by Home Manager — see
#     home-manager/karabiner.nix. We only enable the daemon side here.
#
# No status bar (yabai/skhd/JankyBorders/sketchybar) is installed today —
# AeroSpace alone, no compositor effects.
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.aerospace = {
    enable = true;
    settings = {
      start-at-login = true;
      after-login-command = [];
      after-startup-command = [];

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      automatically-unhide-macos-hidden-apps = false;

      key-mapping.preset = "qwerty";

      gaps = {
        inner.horizontal = 10;
        inner.vertical = 10;
        outer.left = 10;
        outer.bottom = 10;
        outer.top = 10;
        outer.right = 10;
      };

      mode.main.binding = {
        # ── exec ────────────────────────────────────────────────
        # Hyprland: Super, Return, exec, ghostty
        "alt-enter" = "exec-and-forget open -na Ghostty";
        # Hyprland: Super, W, exec, vicinae toggle
        "alt-w" = "exec-and-forget open -a Raycast";

        # ── focus (h/j/k/l + arrows) ───────────────────────────
        # Hyprland: Super, Left/Right/Up/Down, movefocus
        "alt-h" = "focus left";
        "alt-j" = "focus down";
        "alt-k" = "focus up";
        "alt-l" = "focus right";
        "alt-left" = "focus left";
        "alt-down" = "focus down";
        "alt-up" = "focus up";
        "alt-right" = "focus right";

        # ── move window ────────────────────────────────────────
        # Hyprland: Super+Shift, arrows, movewindow
        "alt-shift-h" = "move left";
        "alt-shift-j" = "move down";
        "alt-shift-k" = "move up";
        "alt-shift-l" = "move right";
        "alt-shift-left" = "move left";
        "alt-shift-down" = "move down";
        "alt-shift-up" = "move up";
        "alt-shift-right" = "move right";

        # ── workspaces 1-10 ────────────────────────────────────
        # Hyprland: Super, 1-0, workspace
        "alt-1" = "workspace 1";
        "alt-2" = "workspace 2";
        "alt-3" = "workspace 3";
        "alt-4" = "workspace 4";
        "alt-5" = "workspace 5";
        "alt-6" = "workspace 6";
        "alt-7" = "workspace 7";
        "alt-8" = "workspace 8";
        "alt-9" = "workspace 9";
        "alt-0" = "workspace 10";

        # Hyprland: Super+Shift, 1-0, movetoworkspace
        "alt-shift-1" = "move-node-to-workspace 1";
        "alt-shift-2" = "move-node-to-workspace 2";
        "alt-shift-3" = "move-node-to-workspace 3";
        "alt-shift-4" = "move-node-to-workspace 4";
        "alt-shift-5" = "move-node-to-workspace 5";
        "alt-shift-6" = "move-node-to-workspace 6";
        "alt-shift-7" = "move-node-to-workspace 7";
        "alt-shift-8" = "move-node-to-workspace 8";
        "alt-shift-9" = "move-node-to-workspace 9";
        "alt-shift-0" = "move-node-to-workspace 10";

        # ── workspace nav ──────────────────────────────────────
        # Hyprland: Super, TAB, workspace, previous
        "alt-tab" = "workspace-back-and-forth";
        "alt-shift-tab" = "move-workspace-to-monitor --wrap-around next";

        # ── window state ───────────────────────────────────────
        # Hyprland: Super, Q, killactive
        "alt-q" = "close";
        # Hyprland: Super, F, fullscreen, 1
        "alt-f" = "fullscreen";
        # Hyprland: Super+Alt, Space, togglefloating
        "alt-shift-space" = "layout floating tiling";
        "alt-shift-f" = "layout floating tiling";

        # Layout cycling (no direct Hyprland equivalent — handy on tiling WMs)
        "alt-slash" = "layout tiles horizontal vertical";
        "alt-comma" = "layout accordion horizontal vertical";

        # ── meta ───────────────────────────────────────────────
        "alt-shift-r" = "reload-config";
      };
    };
  };

  # Userspace karabiner.json is written by home-manager/karabiner.nix.
  services.karabiner-elements.enable = true;
}
