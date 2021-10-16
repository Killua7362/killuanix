{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font.name = "JetBrainsMono Nerd Font";
    iconTheme = {
<<<<<<< HEAD
      name = "ePapirus-Dark";
=======
      name = "vimix-dark";
>>>>>>> 633a635364b37cf4b09f87be4e292e437407733b
    };
    theme = {
      name = "Adapta-Nokto-Eta";
    };
  };
}
