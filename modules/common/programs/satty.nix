{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:{
  programs.satty = {
    enable = true;
    settings = {
      general = {
          input-scale = 1.0;
          annotation-size-factor = 1.0;
          output-filename = "/home/killua/Pictures/Screenshots/Screenshots-%Y-%m-%d_%H:%M:%S.png";
          save-after-copy = false;
          actions-on-enter = ["save-to-file"];
      };
    };
  };
}
