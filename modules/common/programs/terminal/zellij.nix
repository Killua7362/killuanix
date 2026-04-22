{
  config,
  pkgs,
  ...
}: let
  p = config.theme.palette;
in {
  programs.zellij = {
    enable = true;
    extraConfig = ''
      keybinds clear-defaults=true {
          locked {
              bind "Ctrl g" { SwitchToMode "normal"; }
          }
          pane {
              bind "left" { MoveFocus "left"; }
              bind "down" { MoveFocus "down"; }
              bind "up" { MoveFocus "up"; }
              bind "right" { MoveFocus "right"; }
              bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
              bind "d" { NewPane "down"; SwitchToMode "normal"; }
              bind "e" { MoveFocus "down"; }
              bind "f" { ToggleFocusFullscreen; SwitchToMode "normal"; }
              bind "h" { NewPane; SwitchToMode "normal"; }
              bind "i" { MoveFocus "up"; }
              bind "j" { TogglePaneEmbedOrFloating; SwitchToMode "normal"; }
              bind "k" { MoveFocus "up"; }
              bind "l" { MoveFocus "right"; }
              bind "n" { MoveFocus "left"; }
              bind "o" { MoveFocus "right"; }
              bind "p" { SwitchFocus; }
              bind "Ctrl p" { SwitchToMode "normal"; }
              bind "r" { NewPane "right"; SwitchToMode "normal"; }
              bind "s" { NewPane "stacked"; SwitchToMode "normal"; }
              bind "u" { TogglePanePinned; SwitchToMode "normal"; }
              bind "w" { ToggleFloatingPanes; SwitchToMode "normal"; }
              bind "z" { TogglePaneFrames; SwitchToMode "normal"; }
          }
          tab {
              bind "left" { GoToPreviousTab; }
              bind "down" { GoToNextTab; }
              bind "up" { GoToPreviousTab; }
              bind "right" { GoToNextTab; }
              bind "1" { GoToTab 1; SwitchToMode "normal"; }
              bind "2" { GoToTab 2; SwitchToMode "normal"; }
              bind "3" { GoToTab 3; SwitchToMode "normal"; }
              bind "4" { GoToTab 4; SwitchToMode "normal"; }
              bind "5" { GoToTab 5; SwitchToMode "normal"; }
              bind "6" { GoToTab 6; SwitchToMode "normal"; }
              bind "7" { GoToTab 7; SwitchToMode "normal"; }
              bind "8" { GoToTab 8; SwitchToMode "normal"; }
              bind "9" { GoToTab 9; SwitchToMode "normal"; }
              bind "[" { BreakPaneLeft; SwitchToMode "normal"; }
              bind "]" { BreakPaneRight; SwitchToMode "normal"; }
              bind "b" { BreakPane; SwitchToMode "normal"; }
              bind "e" { GoToNextTab; }
              bind "h" { NewTab; SwitchToMode "normal"; }
              bind "i" { GoToPreviousTab; }
              bind "j" { GoToNextTab; }
              bind "k" { GoToPreviousTab; }
              bind "l" { GoToNextTab; }
              bind "n" { GoToPreviousTab; }
              bind "o" { GoToNextTab; }
              bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
              bind "s" { ToggleActiveSyncTab; SwitchToMode "normal"; }
              bind "Ctrl t" { SwitchToMode "normal"; }
              bind "x" { CloseTab; SwitchToMode "normal"; }
              bind "tab" { ToggleTab; }
          }
          resize {
              bind "left" { Resize "Increase left"; }
              bind "down" { Resize "Increase down"; }
              bind "up" { Resize "Increase up"; }
              bind "right" { Resize "Increase right"; }
              bind "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
              bind "=" { Resize "Increase"; }
              bind "E" { Resize "Decrease down"; }
              bind "H" { Resize "Decrease left"; }
              bind "I" { Resize "Decrease up"; }
              bind "J" { Resize "Decrease down"; }
              bind "K" { Resize "Decrease up"; }
              bind "L" { Resize "Decrease right"; }
              bind "N" { Resize "Decrease left"; }
              bind "O" { Resize "Decrease right"; }
              bind "e" { Resize "Increase down"; }
              bind "h" { Resize "Increase left"; }
              bind "i" { Resize "Increase up"; }
              bind "j" { Resize "Increase down"; }
              bind "k" { Resize "Increase up"; }
              bind "l" { Resize "Increase right"; }
              bind "n" { Resize "Increase left"; }
              bind "o" { Resize "Increase right"; }
          }
          move {
              bind "left" { MovePane "left"; }
              bind "down" { MovePane "down"; }
              bind "up" { MovePane "up"; }
              bind "right" { MovePane "right"; }
              bind "e" { MovePane "down"; }
              bind "h" { MovePane; }
              bind "Ctrl h" { SwitchToMode "normal"; }
              bind "i" { MovePane "up"; }
              bind "j" { MovePane "down"; }
              bind "k" { MovePane "up"; }
              bind "l" { MovePane "right"; }
              bind "n" { MovePane "left"; }
              bind "o" { MovePane "right"; }
              bind "p" { MovePaneBackwards; }
              bind "tab" { MovePane; }
          }
          scroll {
              bind "n" { HalfPageScrollDown; }
              bind "p" { HalfPageScrollUp; }
              bind "s" { SwitchToMode "entersearch"; SearchInput 0; }
              bind "u" { EditScrollback; SwitchToMode "normal"; }
          }
          search {
              bind "c" { SearchToggleOption "CaseSensitivity"; }
              bind "n" { Search "down"; }
              bind "o" { SearchToggleOption "WholeWord"; }
              bind "p" { Search "up"; }
              bind "u" { HalfPageScrollUp; }
              bind "w" { SearchToggleOption "Wrap"; }
          }
          session {
              bind "a" {
                  LaunchOrFocusPlugin "zellij:about" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "normal"
              }
              bind "c" {
                  LaunchOrFocusPlugin "configuration" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "normal"
              }
              bind "Ctrl o" { SwitchToMode "normal"; }
              bind "p" {
                  LaunchOrFocusPlugin "plugin-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "normal"
              }
              bind "s" {
                  LaunchOrFocusPlugin "zellij:share" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "normal"
              }
              bind "w" {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "normal"
              }
          }
          // "locked"
          shared_except "tmux" {
              bind "Ctrl a" { SwitchToMode "tmux"; }
          }
          //"locked"
          shared {
              bind "Alt left" { MoveFocusOrTab "left"; }
              bind "Alt down" { MoveFocus "down"; }
              bind "Alt up" { MoveFocus "up"; }
              bind "Alt right" { MoveFocusOrTab "right"; }
              bind "Alt +" { Resize "Increase"; }
              bind "Alt -" { Resize "Decrease"; }
              bind "Alt =" { Resize "Increase"; }
              bind "Alt [" { PreviousSwapLayout; }
              bind "Alt ]" { NextSwapLayout; }
              bind "Alt f" { ToggleFocusFullscreen; }
              bind "Ctrl g" { SwitchToMode "locked"; }
              bind "Alt h" { NewPane; }
              bind "Alt Shift i" { MoveTab "left"; }
              bind "Alt j" { MoveFocus "down"; }
              bind "Alt k" { MoveFocus "up"; }
              bind "Alt l" { MoveFocusOrTab "right"; }
              bind "Alt Shift o" { MoveTab "right"; }
              bind "Alt p" { TogglePaneInGroup; }
              bind "Alt Shift p" { ToggleGroupMarking; }
              bind "Ctrl q" { Quit; }
              bind "Alt t" { ToggleFloatingPanes; }
              bind "Ctrl tab" { GoToNextTab; }
              bind "Ctrl Shift tab" { GoToPreviousTab; }
              // bind "ctrl w" { CloseTab; }
          }
          shared_except "locked" {
              bind "Alt n" { MoveFocusOrTab "left"; }
              bind "Alt e" { MoveFocusOrTab "down"; }
              bind "Alt o" { MoveFocusOrTab "right"; }
              bind "Alt i" { MoveFocusOrTab "up"; }
              bind "Alt w" { CloseFocus; }
          }
      //"locked"
          shared_except "move" {
              bind "Ctrl h" { SwitchToMode "move"; }
              bind "Ctrl m" { SwitchToMode "move"; }
          }
          // "locked"
          shared_except  "session" {
              bind "Ctrl o" { SwitchToMode "session"; }
          }
          //"locked"
          shared_except  "scroll" "search" "tmux" {
              bind "Ctrl a" { SwitchToMode "tmux"; }
          }
          //"locked"
          shared_except "scroll" "search" {
              bind "Ctrl s" { SwitchToMode "scroll"; }
          }
          //"locked"
          shared_except  "tab" {
              bind "Ctrl t" { SwitchToMode "tab"; }
          }
          shared_except "locked" "pane" {
              bind "Ctrl p" { SwitchToMode "pane"; }
          }
          shared_except "locked" "resize" "move" {
              bind "Ctrl n" { SwitchToMode "resize"; }
          }
          shared_except "locked" "normal" "entersearch" {
              bind "enter" { SwitchToMode "normal"; }
          }
          shared_except "locked" "normal"  "entersearch" "renametab" "renamepane" {
              bind "esc" { SwitchToMode "normal"; }
          }
          shared_among "resize" "move" {
              bind "Ctrl n" { SwitchToMode "normal"; }
          }
          shared_among "pane" "tmux" {
              bind "x" { CloseFocus; SwitchToMode "normal"; }
          }
          shared_among "scroll" "search" {
              bind "PageDown" { PageScrollDown; }
              bind "PageUp" { PageScrollUp; }
              bind "left" { PageScrollUp; }
              bind "down" { ScrollDown; }
              bind "up" { ScrollUp; }
              bind "right" { PageScrollDown; }
              bind "Ctrl b" { PageScrollUp; }
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "normal"; }
              bind "d" { HalfPageScrollDown; }
              bind "Ctrl d" { PageScrollDown; }
              bind "e" { ScrollDown; }
              bind "Ctrl f" { PageScrollDown; }
              bind "h" { PageScrollUp; }
              bind "i" { ScrollUp; }
              bind "j" { ScrollDown; }
              bind "k" { ScrollUp; }
              bind "l" { PageScrollDown; }
              bind "Ctrl s" { SwitchToMode "normal"; }
              bind "Ctrl u" { PageScrollUp; }
          }
          entersearch {
              bind "Ctrl c" { SwitchToMode "scroll"; }
              bind "esc" { SwitchToMode "scroll"; }
              bind "enter" { SwitchToMode "search"; }
          }
          renametab {
              bind "esc" { UndoRenameTab; SwitchToMode "tab"; }
          }
          shared_among "renametab" "renamepane" {
              bind "Ctrl c" { SwitchToMode "normal"; }
          }
          renamepane {
              bind "esc" { UndoRenamePane; SwitchToMode "pane"; }
          }
          shared_among "session" "tmux" {
              bind "d" { Detach; }
          }
          tmux {
              bind "left" { MoveFocus "left"; SwitchToMode "normal"; }
              bind "down" { MoveFocus "down"; SwitchToMode "normal"; }
              bind "up" { MoveFocus "up"; SwitchToMode "normal"; }
              bind "right" { MoveFocus "right"; SwitchToMode "normal"; }
              bind "space" { NextSwapLayout; }
              bind "\"" { NewPane "down"; SwitchToMode "normal"; }
              bind "%" { NewPane "right"; SwitchToMode "normal"; }
              bind "," { SwitchToMode "renametab"; }
              bind "[" { SwitchToMode "scroll"; }
              bind "Ctrl b" { Write 2; SwitchToMode "normal"; }
              bind "c" { NewTab; SwitchToMode "normal"; }
              bind "e" { MoveFocus "down"; SwitchToMode "normal"; }
              bind "h" { MoveFocus "left"; SwitchToMode "normal"; }
              bind "i" { MoveFocus "up"; SwitchToMode "normal"; }
              bind "j" { MoveFocus "down"; SwitchToMode "normal"; }
              bind "k" { MoveFocus "up"; SwitchToMode "normal"; }
              bind "l" { MoveFocus "right"; SwitchToMode "normal"; }
              bind "n" { MoveFocus "left"; SwitchToMode "normal"; }
              bind "o" { MoveFocus "right"; SwitchToMode "normal"; }
              bind "Shift o" { FocusNextPane; }
              bind "p" { GoToPreviousTab; SwitchToMode "normal"; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
          }
      }

      plugins {
          about location="zellij:about"
          compact-bar location="zellij:compact-bar"
          configuration location="zellij:configuration"
          filepicker location="zellij:strider" {
              cwd "/"
          }
          plugin-manager location="zellij:plugin-manager"
          session-manager location="zellij:session-manager"
          status-bar location="zellij:status-bar"
          strider location="zellij:strider"
          tab-bar location="zellij:tab-bar"
          welcome-screen location="zellij:session-manager" {
              welcome_screen true
          }
          autolock location="https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm" {
              is_enabled true
              triggers "nvim|vim|git|fzf|zoxide|atuin|git-forgit|lazygit|claude"
              reaction_seconds "0.3"
              print_to_log true
          }
      }

      load_plugins {
        autolock
      }
      web_client {
          font "monospace"
      }

      themes {
        custom {
          fg "${p.fg}"
          bg "${p.zellij_bg}"
          black "${p.bg}"
          red "${p.color1}"
          green "${p.color2}"
          yellow "${p.color3}"
          blue "${p.color4}"
          magenta "${p.color5}"
          cyan "${p.color6}"
          white "${p.color15}"
          orange "${p.color9}"

          text_unselected {
            base "${p.fg}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          text_selected {
            base "${p.bg}"
            background "${p.color4}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          ribbon_selected {
            base "${p.bg}"
            background "${p.color4}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          ribbon_unselected {
            base "${p.fg}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          table_title {
            base "${p.color4}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          table_cell_selected {
            base "${p.bg}"
            background "${p.color4}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          table_cell_unselected {
            base "${p.fg}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          list_selected {
            base "${p.bg}"
            background "${p.color4}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          list_unselected {
            base "${p.fg}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          exit_code_success {
            base "${p.color2}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          exit_code_error {
            base "${p.color1}"
            background "${p.zellij_bg}"
            emphasis_0 "${p.color4}"
            emphasis_1 "${p.color9}"
            emphasis_2 "${p.color3}"
            emphasis_3 "${p.color5}"
          }
          multiplayer_user_colors {
            player_1 "${p.color4}"
            player_2 "${p.color5}"
            player_3 "${p.color6}"
            player_4 "${p.color3}"
            player_5 "${p.color9}"
            player_6 "${p.color2}"
            player_7 "${p.color1}"
            player_8 "${p.color12}"
            player_9 "${p.color13}"
            player_10 "${p.color14}"
          }
          frame_selected {
            base "${p.color0}"
            emphasis_0 "${p.color9}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
          frame_highlight {
            base "${p.color9}"
            emphasis_0 "${p.color1}"
            emphasis_1 "${p.color3}"
            emphasis_2 "${p.color2}"
            emphasis_3 "${p.color5}"
          }
        }
      }
      theme "custom"

      default_shell "zsh"
      default_layout "default"

      pane_frames true
      ui {
          pane_frames {
              rounded_corners true
              hide_session_name false
          }
      }

      copy_command "wl-copy"                    // wayland
      show_startup_tips false

      env {
        WAYLAND_DISPLAY "wayland-1"
      }
    '';
  };
}
