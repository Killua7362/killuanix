{pkgs, ...}: let
  handler = type:
    pkgs.writeShellScript "cliphist-${type}-handler" ''
      cliphist store
      qs ipc call cliphistService update 2>/dev/null || true
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
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${handler "text"}";
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
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${handler "image"}";
        Restart = "always";
        RestartSec = 1;
        KillMode = "mixed";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
