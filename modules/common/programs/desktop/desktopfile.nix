{ config
, pkgs
, lib
, inputs
, ...
}: {
  xdg.desktopEntries.google-chrome-sock = {
    name = "google-chrome-sock";
    exec = "${pkgs.writeShellScript "google-chrome-sock" ''
      exec ${pkgs.google-chrome}/bin/google-chrome-stable \
        --proxy-server="socks5://127.0.0.1:1080" \
        --proxy-bypass-list="<-loopback>" \
        --user-data-dir="$HOME/.config/teams-vpn-chrome" \
        --no-first-run \
        --ignore-certificate-errors \
        "$@"
    ''} %u";
    icon = "google-chrome";
    terminal = false;
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "x-scheme-handler/google-chrome" ];
  };
}
