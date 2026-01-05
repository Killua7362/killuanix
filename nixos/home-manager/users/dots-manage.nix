{
  pkgs,
  config,
  ...
}: {
  xdg.configFile = {
    "/home/killua/.config/aconfmgr" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/aconfmgr;
      recursive = true;
    };
    "/home/killua/.config/handlr" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/handlr;
      recursive = true;
    };
    "/home/killua/.config/rofi" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/rofi;
      recursive = true;
    };
    "/home/killua/.config/satty" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/satty;
      recursive = true;
    };
    "/home/killua/.ideavimrc" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/ideavimrc;
    };
    "/home/killua/.config/sway" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/sway;
      recursive = true;
    };
    "/home/killua/.config/ags" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/ags;
      recursive = true;
    };
    "/home/killua/.config/matugen" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/matugen;
      recursive = true;
    };
    "/home/killua/.config/niri" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/niri;
      recursive = true;
    };
    "/home/killua/.config/walker" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/walker;
      recursive = true;
    };
    "/home/killua/.config/zellij" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/zellij;
      recursive = true;
    };
    #     "/home/killua/.gitconfig" =
    #      {
    #         source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/gitconfig;
    #        };
    "/home/killua/.gitignore_global" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/gitignore_global;
    };
  };
}
