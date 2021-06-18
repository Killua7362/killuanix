{ pkgs, config, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacsGit;
    extraPackages = (epkgs: (with epkgs;[ company ]));
  };
  services.emacs = {
    enable = true;
  };
  #  xdg.configFile."/home/killua/.doom.d" =
  #   {
  #     source = config.lib.file.mkOutOfStoreSymlink /home/killua/Nix-Config/DotFiles/.doom.d;
  #     recursive = true;
  #   };
  home = {
    sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];
    sessionVariables = {
      DOOMDIR = "${config.xdg.configHome}/doom-config";
      DOOMLOCALDIR = "${config.xdg.configHome}/doom-local";
    };
  };

  xdg.configFile = {
    "doom-config/config.el" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/Nix-Config/DotFiles/doom/config.el;
    };
    "doom-config/init.el" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/Nix-Config/DotFiles/doom/init.el;
    };
    "doom-config/packages.el" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/Nix-Config/DotFiles/doom/packages.el;
    };
    "emacs" = {
      source = pkgs.fetchgit {
        url = "https://github.com/hlissner/doom-emacs";
        rev = "f95bf845c3e8eb065637e9a773d5a61819d69d8d";
        sha256 = "r++KApLSat6cNyGvpt6PJ+g1ClS36VR+em3ZXUgQzBc=";
      };
      onChange = "${pkgs.writeShellScript "doom-change" ''
          export DOOMDIR="${config.home.sessionVariables.DOOMDIR}"
          export DOOMLOCALDIR="${config.home.sessionVariables.DOOMLOCALDIR}"
          if [ ! -d "$DOOMLOCALDIR" ]; then
            ${config.xdg.configHome}/emacs/bin/doom -y install
          else
            ${config.xdg.configHome}/emacs/bin/doom -y sync -u
          fi
        ''}";
    };
  };

}
