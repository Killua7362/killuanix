{pkgs, ...}: let
  # Backend store for the `clipboard-history` wofi picker (Super+V, see
  # utils/clipboard-history.nix) and the `cliphist-viewer` web UI. Stores the
  # clip, then records `<newest-id>\t<iso8601>` into a timestamp sidecar —
  # cliphist itself keeps no timestamps, and the viewer reads this file to offer
  # date filtering + a timestamped CSV export. Newest id is line 1 of the list
  # right after a synchronous store. Sidecar grows unbounded (append-only); it's
  # cheap text and cliphist's own store cap bounds what's actually shown.
  store = pkgs.writeShellScript "cliphist-store-stamped" ''
    ${pkgs.cliphist}/bin/cliphist store
    ts_file="$HOME/.cache/cliphist/timestamps"
    id=$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.coreutils}/bin/head -n1 | ${pkgs.coreutils}/bin/cut -f1)
    [ -n "$id" ] && printf '%s\t%s\n' "$id" "$(${pkgs.coreutils}/bin/date -Iseconds)" >> "$ts_file"
  '';
in {
  systemd.user.services = {
    cliphist-text = {
      Unit = {
        Description = "cliphist text clipboard watcher";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${store}";
        Restart = "always";
        RestartSec = 1;
        KillMode = "mixed";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
    cliphist-image = {
      Unit = {
        Description = "cliphist image clipboard watcher";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${store}";
        Restart = "always";
        RestartSec = 1;
        KillMode = "mixed";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
