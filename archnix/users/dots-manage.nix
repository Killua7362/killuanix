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
        "nvim" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/nvim;
          recursive = true;
        };
        "picom" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/picom;
          recursive = true;
        };
        "/home/killua/.zprofile" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/archnix/.zprofile;
        };
        "/home/killua/.zshrc" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/archnix/.zshrc;
        };
        "qutebrowser" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/qutebrowser;
          recursive = true;
        };
        "mpv" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/mpv;
          recursive = true;
        };
        "ranger" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/ranger;
          recursive = true;
        };
        "/home/killua/.tmux.conf.local" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/.tmux/.tmux.conf.local;
        };
        "/home/killua/.tmux.conf" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/.tmux/.tmux.conf;
        };
        "alacritty" =
        {
          source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/alacritty;
          recursive = true;
        };
	"kitty"=
	{
	source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/kitty;
	recursive = true;
	};
	"/home/killua/.zsh/agnoster.zsh" =
	{
	source = config.lib.file.mkOutOfStoreSymlink /home/killua/archnix/DotFiles/.zsh/agnoster.zsh;
	};
    };
}
