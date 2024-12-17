{ pkgs, config, ... }:
{

  xdg.configFile =
    {
      "/home/killua/.config/awesome" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/awesome;
          recursive = true;
        };
      "/home/killua/.config/zathura" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/zathura;
          recursive = true;
        };
      "/home/killua/.config/nvim" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/nvim;
          recursive = true;
        };

      "/home/killua/.zprofile" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/.zprofile;
        };
      "/home/killua/.zshrc" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/archnix/.zshrc;
        };

      "/home/killua/.lesskey" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/.lesskey;
        };
      "/home/killua/.zsh_plugins" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/zsh_plugins;
          recursive = true;
        };

      "/home/killua/.config/mpv" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/mpv;
          recursive = true;
        };
      "/home/killua/.config/ranger" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/ranger;
          recursive = true;
        };
      "/home/killua/.tmux.conf.local" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/.tmux/.tmux.conf.local;
        };
      "/home/killua/.tmux.conf" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/.tmux/.tmux.conf;
        };
      "/home/killua/.config/kitty" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/kitty;
          recursive = true;
        };
      "/home/killua/.config/wezterm" = 
      {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/wezterm;
          recursive = true;
      };
      "/home/killua/.config/yazi" = 
      {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/yazi;
          recursive = true;
      };
      "/home/killua/.config/lazygit.yml" = 
      {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/lazygit.yml;
      };
    };
}
