# Darwin system entry for the macnix host.
#
# Mirrors chrollo/configuration.nix: this module is system-only. Home Manager
# now lives in a separate flake output (homeManagerConfigurations.macnix) and
# is applied with its own switch (`home-manager switch --flake .#macnix` or
# via scripts/nix_switch).
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./settings.nix
    ./brew.nix
    ./services.nix
    ./packages
    ./packages/nix-index.nix
    ./packages/pam.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
    };
    overlays =
      (lib.attrValues inputs.self.customOverlays)
      ++ [
        (final: prev:
          lib.optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
            inherit (final.pkgs-x86) idris2;
          })
      ];
  };

  nix.nixPath = {nixpkgs = "${inputs.nixpkgs-unstable}";};

  users.users.killua = {
    home = "/Users/killua";
  };

  networking.computerName = "killua";
  networking.hostName = "killua";
  networking.knownNetworkServices = ["Wi-Fi" "USB 10/100 LAN"];

  system.stateVersion = 4;
}
