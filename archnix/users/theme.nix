{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font.name = "JetBrainsMono Nerd Font";
    iconTheme = {
      name = "ePapirus-Dark";
    };
    theme = {
      name = "Adapta-Nokto-Eta";
    };
  };
}
