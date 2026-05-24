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
}
