{ lib, ... }:
let
  envAttrs = {
    QT_IM_MODULE="fcitx";
    XMODIFIERS="@im=fcitx";
    SDL_IM_MODULE="fcitx";
    GLFW_IM_MODULE="ibus";
    INPUT_METHOD="fcitx";
    ELECTRON_OZONE_PLATFORM_HINT="auto";
    XDG_MENU_PREFIX="plasma";
    WLR_DRM_NO_ATOMIC="1";
    WLR_NO_HARDWARE_CURSORS="1";
    ILLOGICAL_IMPULSE_VIRTUAL_ENV="~/.local/state/quickshell/.venv";
    TERMINAL="kitty";
    XDG_SESSION_TYPE="wayland";
    XDG_CURRENT_DESKTOP="Hyprland";
    XDG_SESSION_DESKTOP="Hyprland";
    QT_QPA_PLATFORMTHEME="gtk3";
    QT_QPA_PLATFORMTHEME_QT6="gtk3";
    USE_LAYER_SHELL="0";
    ACCESSIBILITY_ENABLED="1";
    GTK_MODULES="gail:atk-bridge";
    OOO_FORCE_DESKTOP="gnome";
    GNOME_ACCESSIBILITY ="1";
    QT_ACCESSIBILITY ="1";
    QT_LINUX_ACCESSIBILITY_ALWAYS_ON ="1";
    WAYLAND_DISPLAY="wayland-1";
  };
in {
  wayland.windowManager.hyprland.settings = {
    env = builtins.mapAttrs (n: v: "${n},${v}") envAttrs;
  };
}
