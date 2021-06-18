{ pkgs, config, ... }:


{

  xdg.configFile =
    {
      "/home/killua/.alacritty.yml" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/alacritty.yml;
        };
#      "/home/killua/.mozilla" =
#        {
#          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/Personal-Dots/mozilla;
#          recursive = true;
#        };
      "awesome" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/awesome;
          recursive = true;
        };
      "zathura" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/zathura;
          recursive = true;
        };
        "/home/killua/.wezterm.lua" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/wezterm.lua;
          recursive = true;
        };
        "/home/killua/.config/nvim" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/nvim;
          recursive = true;
        };

    };
}
