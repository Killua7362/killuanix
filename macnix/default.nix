{config, ...}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      /*
      allowUnsupportedSystem = true;
      */
    };
    overlays = attrValues self.overlays ++ singleton (final: prev: (optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
      inherit (final.pkgs-x86) idris2;
    }));
  };
  nix.nixPath = {nixpkgs = "${inputs.nixpkgs-unstable}";};
  users.users."killua" = {
    home = "/Users/killua";
  };
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users."killua" = {
    imports =
      attrValues self.homeManagerModules
      ++ [
        ./macnix/home.nix
      ];
  };

  networking.computerName = "killua";
  networking.hostName = "killua";
  networking.knownNetworkServices = ["Wi-Fi" "USB 10/100 LAN"];
}
