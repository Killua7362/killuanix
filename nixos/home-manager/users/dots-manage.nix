{
  pkgs,
  config,
  ...
}: {
  xdg.configFile = {
    "/home/killua/.config/zathura" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/zathura;
      recursive = true;
    };
    "/home/killua/.lesskey" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/.lesskey;
    };
    "/home/killua/.config/mpv" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/mpv;
      recursive = true;
    };
    "/home/killua/.config/ranger" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/ranger;
      recursive = true;
    };
    "/home/killua/.tmux.conf.local" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/.tmux/.tmux.conf.local;
    };
    "/home/killua/.tmux.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/.tmux/.tmux.conf;
    };
    "/home/killua/.config/kitty" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/kitty;
      recursive = true;
    };
    "/home/killua/.config/wezterm" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/wezterm;
      recursive = true;
    };
    "/home/killua/.config/yazi" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/yazi;
      recursive = true;
    };
    "/home/killua/.config/lazygit.yml" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/lazygit.yml;
    };

    "/home/killua/.config/ghostty" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/ghostty;
      recursive = true;
    };

    "/home/killua/.config/aconfmgr" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/aconfmgr;
      recursive = true;
    };
    "/home/killua/.config/ueli" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/ueli;
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
    "/home/killua/.config/DankMaterialShell" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/DankMaterialShell;
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
