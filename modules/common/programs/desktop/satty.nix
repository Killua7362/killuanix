{ config
, pkgs
, lib
, inputs
, ...
}: {
  programs.satty = {
    enable = true;
    settings = {
      general = {
        annotation-size-factor = 1.0;
        output-filename = "/home/killua/Pictures/Screenshots/Screenshots-%Y-%m-%d_%H:%M:%S.png";
        save-after-copy = false;
        actions-on-enter = [ "save-to-file" ];
        early-exit = true;
        copy-command = "wl-copy --type image/png";
        initial-tool="brush";
      };
    };
  };
}
