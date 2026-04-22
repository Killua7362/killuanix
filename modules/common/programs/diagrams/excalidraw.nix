# Excalidraw launcher — opens the containerised web UI at http://localhost:8899
# in an app-mode chromium window (falls back to the default browser via
# xdg-open when chromium is absent). The container itself is defined in
# modules/containers/excalidraw.nix (NixOS only); on Arch / Darwin the wrapper
# will still run but the target port will be unreachable until the user brings
# up their own Excalidraw instance.
#
# Note: stock Excalidraw has no URL-scene loader, so `.excalidraw` files are
# NOT routed here via xdg-open — opening one that way falls through to the
# JSON handler (nvim). Use Excalidraw's in-app "Open" button to load files.
{
  pkgs,
  lib,
  ...
}: let
  url = "http://localhost:8899";

  excalidrawLauncher = pkgs.writeShellApplication {
    name = "excalidraw";
    runtimeInputs = [pkgs.xdg-utils];
    text = ''
      if command -v chromium >/dev/null 2>&1; then
        exec chromium --app=${url} "$@"
      elif command -v google-chrome-stable >/dev/null 2>&1; then
        exec google-chrome-stable --app=${url} "$@"
      else
        exec xdg-open ${url}
      fi
    '';
  };

  excalidrawDesktop = pkgs.makeDesktopItem {
    name = "excalidraw";
    desktopName = "Excalidraw";
    comment = "Virtual whiteboard for hand-drawn diagrams (local container)";
    exec = "${excalidrawLauncher}/bin/excalidraw";
    icon = "applications-graphics";
    categories = ["Graphics" "Development"];
    terminal = false;
  };
in {
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    excalidrawLauncher
    excalidrawDesktop
  ];
}
