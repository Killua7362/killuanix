
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

   
}
           # Link apps installed by home-manager.
      #        home.activation = {
      #          aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #            sudo ln -sfn $genProfilePath/home-path/Applications/ "/Applications/HomeManagerApps"
      #          '';
      #        };
