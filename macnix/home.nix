{ config, lib, pkgs,inputs, ... }:
{

  imports = [
    ./dots-manage.nix
  ];
  home.packages = with pkgs; [
    fd
    skim
    fzf
    tldr
    antigen
   # rnix-lsp
    prefmanager
    cht-sh
  ];
home.stateVersion = "24.05";

    programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    # zsh.enable = true; # see note on other shells below
  };

  home.sessionVariables = {
    TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
      };
  }
# Link apps installed by home-manager.
#        home.activation = {
#          aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
#            sudo ln -sfn $genProfilePath/home-path/Applications/ "/Applications/HomeManagerApps"
#          '';
#        };
   # nodePackages.alfred-incognito-browser
