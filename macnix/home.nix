
{ config, lib, pkgs, ... }:
{
          
  imports = [
    ./dots-manage.nix
  ];
      home.packages = with pkgs; [
          fd

      #    KeyttyApp
      ];

              # Link apps installed by home-manager.
      #        home.activation = {
      #          aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #            sudo ln -sfn $genProfilePath/home-path/Applications/ "/Applications/HomeManagerApps"
      #          '';
      #        };
}