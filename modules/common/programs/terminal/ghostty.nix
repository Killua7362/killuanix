{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;
in {
  programs.ghostty = {
    enable = lib.mkDefault pkgs.stdenv.isLinux;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 12;

      window-decoration = false;
      window-padding-x = 12;
      window-padding-y = 12;
      background-opacity = 1.0;

      cursor-style = "bar";
      cursor-style-blink = true;
      shell-integration = "zsh";
      copy-on-select = "clipboard";
      scrollback-limit = 1000000;

      command = "zsh";

      background = p.bg;
      foreground = p.fg;
      cursor-color = p.cursor;
      cursor-text = p.cursor_text;
      selection-background = p.selection_bg;
      selection-foreground = p.selection_fg;

      palette = [
        "0=${p.color0}"
        "1=${p.color1}"
        "2=${p.color2}"
        "3=${p.color3}"
        "4=${p.color4}"
        "5=${p.color5}"
        "6=${p.color6}"
        "7=${p.color7}"
        "8=${p.color8}"
        "9=${p.color9}"
        "10=${p.color10}"
        "11=${p.color11}"
        "12=${p.color12}"
        "13=${p.color13}"
        "14=${p.color14}"
        "15=${p.color15}"
      ];

      keybind = [
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+n=new_window"
        "ctrl+plus=increase_font_size:1"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+0=reset_font_size"
        # Ctrl-Backspace → ^W (word delete in zsh/fish/readline).
        # Ghostty default sends ^H which most shells treat as plain backspace.
        "ctrl+backspace=text:\\x17"
        # Pass tmux mode-switch and action keys through to the terminal.
        "ctrl+a=unbind"
        "ctrl+g=unbind"
        "ctrl+h=unbind"
        "ctrl+n=unbind"
        "ctrl+o=unbind"
        "ctrl+p=unbind"
        "ctrl+q=unbind"
        "ctrl+s=unbind"
        "ctrl+t=unbind"
        "ctrl+w=unbind"
        # Ctrl-Tab / Ctrl-Shift-Tab → emit Alt-./Alt-, so tmux's existing
        # `bind -n M-.` / `bind -n M-,` (next/previous-window) fire.
        # CSI u (\e[9;5u / \e[9;6u) was attempted but tmux 3.6a normalizes
        # the decoded key (Tab=^I collides with Ctrl modifier) and forwards
        # legacy \e[Z to the pane without matching any C-Tab/C-S-Tab/User
        # bind. Alt-comma/period are legacy escape sequences and travel
        # through tmux unchanged.
        "ctrl+tab=text:\\x1b."
        "ctrl+shift+tab=text:\\x1b,"
      ];
    };
  };
}
