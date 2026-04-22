{
  config,
  pkgs,
  lib,
  ...
}: {
  # DMS owns the matugen pipeline and ships templates for kitty, GTK3/4,
  # qt5ct/qt6ct, firefox (userChrome), and pywalfox. We just install the
  # detection-gated helper packages so DMS picks them up, and the addon
  # wiring lives in browsers/firefox/default.nix.
  #
  # Wallpaper-driven theming for kitty / starship / zellij / qutebrowser is
  # intentionally disabled — those apps use the static palette defined in
  # their own nix modules.
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = with pkgs; [
      matugen # in case DMS doesn't bring it
      pywalfox-native # firefox dynamic theming (needs addon + `pywalfox install`)
      qt6Packages.qt6ct # lets DMS detect + theme Qt6 apps
      libsForQt5.qt5ct # same for Qt5
    ];
  };
}
