{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  p = config.theme.palette;
in {
  programs.kitty = {
    enable = lib.mkDefault (pkgs.stdenv.isLinux);
    settings = {
      window_padding_width = 12;
      background_opacity = "1.00";
      background_blur = 32;
      hide_window_decorations = true;
      cursor_shape = "block";
      cursor_blink_interval = 1;
      scrollback_lines = 3000;
      copy_on_select = true;
      strip_trailing_spaces = "smart";
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12.0;
      tab_bar_style = "powerline";
      tab_bar_align = "left";
      shell_integration = "enabled";
    };
    keybindings = {
      "ctrl+shift+n" = "new_window";
      "ctrl+plus" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
      "ctrl+t" = "no_op";
      "ctrl+n" = "no_op";
      "ctrl+tab" = "no_op";
      "ctrl+shift+tab" = "no_op";
      "ctrl+w" = "no_op";
    };
    extraConfig = ''
      shell zsh
      cursor ${p.cursor}
      cursor_text_color ${p.cursor_text}
      foreground            ${p.fg}
      background            ${p.bg}
      selection_foreground  ${p.selection_fg}
      selection_background  ${p.selection_bg}
      url_color             ${p.url}
      color0  ${p.color0}
      color1  ${p.color1}
      color2  ${p.color2}
      color3  ${p.color3}
      color4  ${p.color4}
      color5  ${p.color5}
      color6  ${p.color6}
      color7  ${p.color7}
      color8  ${p.color8}
      color9  ${p.color9}
      color10 ${p.color10}
      color11 ${p.color11}
      color12 ${p.color12}
      color13 ${p.color13}
      color14 ${p.color14}
      color15 ${p.color15}
    '';
  };
}
