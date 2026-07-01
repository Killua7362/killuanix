{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # google-chrome-sock — Chrome routed through boeingvpn-ui SOCKS5
  # (127.0.0.1:1080). Uses `--proxy-server=socks5://` so Chrome does
  # proxy-side DNS (socks5h behavior) — required for Boeing's split-
  # horizon DNS on Microsoft 365 / Outlook.
  #
  # For dev VNet 10.55.* URLs use the separate `avd-chrome` launcher
  # (modules/common/programs/cloud/azure-bastion) which proxies through
  # bastion-sql's ssh -D :11180 with its own user-data-dir.
  xdg.desktopEntries.google-chrome-sock = {
    name = "google-chrome-sock";
    exec = "${pkgs.writeShellScript "google-chrome-sock" ''
      exec ${pkgs.google-chrome}/bin/google-chrome-stable \
        --proxy-server="socks5://127.0.0.1:1080" \
        --proxy-bypass-list="127.0.0.1" \
        --user-data-dir="$HOME/.config/teams-vpn-chrome" \
        --no-first-run \
        --ignore-certificate-errors \
        "$@"
    ''} %u";
    icon = "google-chrome";
    terminal = false;
    type = "Application";
    categories = ["Network" "WebBrowser"];
    mimeType = ["x-scheme-handler/google-chrome"];
  };

  # nwg-displays — override the upstream launcher (same id shadows the package
  # entry via ~/.local/share/applications precedence). Redirects the persist
  # output to $XDG_RUNTIME_DIR throwaways (-m/-w) so launching it from the app
  # menu never clobbers the declarative lua monitor layout
  # (device-monitors.lua) or the read-only pinned hyprland.conf. It still
  # applies live via `hyprctl keyword monitor`, which is the on-the-fly repos
  # we want; a hyprland reload snaps back to lua. Persist a layout by copying
  # values into the host's device-monitors.lua. See hyprland/CLAUDE.md Monitors.
  xdg.desktopEntries.nwg-displays = {
    name = "Displays Settings";
    genericName = "Output configuration utility";
    comment = "Visual monitor layout (live via hyprctl; persist output discarded)";
    exec = "${pkgs.writeShellScript "nwg-displays-ephemeral" ''
      exec ${pkgs.nwg-displays}/bin/nwg-displays \
        -m "''${XDG_RUNTIME_DIR:-/tmp}/nwg-monitors.conf" \
        -w "''${XDG_RUNTIME_DIR:-/tmp}/nwg-workspaces.conf"
    ''}";
    icon = "nwg-displays";
    terminal = false;
    type = "Application";
    categories = ["Settings" "DesktopSettings"];
  };
}
