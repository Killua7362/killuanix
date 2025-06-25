{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      package = pkgs.nerd-fonts.jetbrains-mono;
    };
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };  
  };
      qt = {
        enable = true;
    };
}
