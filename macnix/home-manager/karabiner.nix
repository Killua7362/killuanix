# Userspace Karabiner-Elements config.
#
# Karabiner-Elements reads ~/.config/karabiner/karabiner.json. We build that
# JSON declaratively from a Nix attrset — no goku, no .edn intermediate.
# Karabiner-Elements auto-reloads on file change, so a `home-manager switch`
# is enough to pick up edits.
#
# One-time setup gotcha: if Karabiner-Elements has already created its own
# karabiner.json, Home Manager will refuse to overwrite it. Move the
# existing config aside before the first switch:
#   mv ~/.config/karabiner ~/.config/karabiner.bak
{
  config,
  lib,
  pkgs,
  ...
}: let
  swapCapsEsc = {
    description = "Swap CapsLock and Escape";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "caps_lock";
          modifiers.optional = ["any"];
        };
        to = [{key_code = "escape";}];
      }
      {
        type = "basic";
        from = {
          key_code = "escape";
          modifiers.optional = ["any"];
        };
        to = [{key_code = "caps_lock";}];
      }
    ];
  };

  karabinerJson = {
    global = {
      check_for_updates_on_startup = false;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
    };
    profiles = [
      {
        name = "Default";
        selected = true;
        virtual_hid_keyboard = {keyboard_type_v2 = "ansi";};
        complex_modifications.rules = [swapCapsEsc];
        simple_modifications = [];
      }
    ];
  };
in {
  home.file.".config/karabiner/karabiner.json".text =
    builtins.toJSON karabinerJson;
}
