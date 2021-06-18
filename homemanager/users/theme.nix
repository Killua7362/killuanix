{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font.name = "JetBrainsMono Nerd Font";
    iconTheme = {
      name = "Papirus-Dark";
    };
    theme = {
      name = "Adapta-Nokto";
    };
  };
}
