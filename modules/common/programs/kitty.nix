{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:{
    programs.kitty = {
      enable = lib.mkDefault (pkgs.stdenv.isLinux);
      settings = {
        window_padding_width = 12;
        background_opacity = "1.00";
        background_blur = 32;
        hide_window_decorations=true;
        cursor_shape="block";
        cursor_blink_interval=1;
        scrollback_lines=3000;
        copy_on_select=true;
        strip_trailing_spaces="smart";
        font_family="JetBrainsMono Nerd Font";
        font_size=12.0;
        tab_bar_style="powerline";
        tab_bar_align="left";
        shell_integration="enabled";
      };
      keybindings = {
        "ctrl+shift+n"="new_window";
        "ctrl+plus"="change_font_size all +1.0";
        "ctrl+minus"="change_font_size all -1.0";
        "ctrl+0"="change_font_size all 0";
        "ctrl+t"="no_op";
        "ctrl+n"="no_op";
        "ctrl+tab"="no_op";
        "ctrl+shift+tab"="no_op";
        "ctrl+w"="no_op";
      };
      extraConfig = ''
            shell zsh
            cursor #e2e2e2
            cursor_text_color #c6c6c6
            foreground            #e2e2e2
            background            #131313
            selection_foreground  #21323f
            selection_background  #b7c9d9
            url_color             #89ceff
            color8   #262626
            color0   #4c4c4c
            color1   #ac8a8c
            color9   #c49ea0
            color2   #8aac8b
            color10  #9ec49f
            color3   #aca98a
            color11  #c4c19e
            color4  #89ceff
            color12 #a39ec4
            color5   #ac8aac
            color13  #c49ec4
            color6   #8aacab
            color14  #9ec3c4
            color15   #e7e7e7
            color7  #f0f0f0
      '';
    };
}
