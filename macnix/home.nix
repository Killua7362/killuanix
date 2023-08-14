{ config, lib, pkgs, ... }:
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
    rnix-lsp
    prefmanager
  ];


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
