{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:{
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard="clipboard";
      smooth-scroll=true;
      font="JetBrainsMono Nerd Font Mono 15";
      page-padding=10;
      scroll-wrap=true;
      statusbar-home-tilde=true;
    };
    mappings = {
        "r"="reload";
        "e"="scroll down";
        "i"="scroll up";
        "n"="scroll left";
        "o"="scroll right";
        "."="scroll half-up";
        ">"="scroll page-top";
        "E"="scroll page-bottom";
        "<A-.>"="scroll full-up";
        "<A-e>"="scroll full-down";
        "<PageUp>"="scroll half-up";
        "<PageDown>"="scroll half-down";
        "<BackSpace>"="scroll half-up";
        "<Space>"="scroll half-down";
        "h"="navigate previous";
        "b"="adjust_window best-fit";
        "H"="adjust_window best-fit";
        "w"="adjust_window width";
        "W"="adjust_window width";
        "p"="rotate rotate-ccw";
        "<Left>"="rotate rotate-ccw";
        ","="rotate rotate-cw";
        "<Right>"="rotate rotate-cw";
        "<A-g>"="goto";
        "g"="reload";
        "c"="recolor";
        "u"="follow";
        "<Return>"="toggle_presentation";
        "Q"="quit";
        "[presentation] <Return>"="toggle_presentation";
        "[index] i"="toggle_index";
        "[index] ."="navigate_index up";
        "[index] e"="navigate_index down";
        "[index] u"="navigate_index select";
        "[index] +"="navigate_index expand";
        "[index] -"="navigate_index collapse";
        "[index] <Tab>"="navigate_index toggle";
        "[index] <ShiftTab>"="navigate_index expand-all";
        "[index] <A-ShiftTab>"="navigate_index collapse-all";
    };
  };
}
