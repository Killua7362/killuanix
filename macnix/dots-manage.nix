{ pkgs, config, ... }:
{

  xdg.configFile =
    {
      "/Users/killua/.config/zathura" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/zathura;
          recursive = true;
        };
        "/Users/killua/.config/nvim" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/nvim;
          recursive = true;
        };
  
        "/Users/killua/.zprofile" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/.zprofile;
        };
        "/Users/killua/.zshrc" =
        {
           source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/.zshrc;
         };

        "/Users/killua/.config/mpv" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/mpv;
          recursive = true;
        };
        "/Users/killua/.config/ranger" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/ranger;
          recursive = true;
        };
        "/Users/killua/.tmux.conf.local" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/.tmux/.tmux.conf.local;
        };
        "/Users/killua/.tmux.conf" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/.tmux/.tmux.conf;
        };
          "/Users/killua/.config/karabiner" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/karabiner;
          recursive = true;
        };
    };
}
