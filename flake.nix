{
  nixConfig = {
    extra-substituters = [
    "https://hyprland.cachix.org"
    "https://vicinae.cachix.org"
    "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    homemanager = {
      url = "github:rycee/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    comma = {
      url = "github:Shopify/comma";
      flake = false;
    };
    emacs.url = "github:nix-community/emacs-overlay";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    prefmanager.url = "github:malob/prefmanager";
    prefmanager.inputs.nixpkgs.follows = "nixpkgs";
    prefmanager.inputs.flake-compat.follows = "flake-compat";
    prefmanager.inputs.flake-utils.follows = "flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    mk-darwin-system.url = "github:vic/mk-darwin-system/main";
    spacebar.url = "github:cmacrae/spacebar/v1.3.0";
    nixgl.url = "github:nix-community/nixGL";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # nixos specific packages
    nixospkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixospkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixospkgs";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixospkgs-unstable";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    vicinae.url = "github:vicinaehq/vicinae";

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixospkgs-unstable";
    };

    nixCats.url = "github:BirdeeHub/nixCats-nvim";
  };

  outputs = inputs @ {
    self,
    flake-utils,
    homemanager,
    home-manager,
    nixpkgs,
    neovim-nightly-overlay,
    nur,
    emacs,
    darwin,
    mk-darwin-system,
    nixgl,
    nix-flatpak,
    nixospkgs,
    ...
  }: let
    inherit (darwin.lib) darwinSystem;
    inherit
      (inputs.nixpkgs-unstable.lib)
      attrValues
      makeOverridable
      optionalAttrs
      singleton
      ;

    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    overlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    commonModules = import ./modules/common;
    crossPlatformModules = import ./modules/cross-platform;

    nixosConfigurations = {
      killua = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./nixos/configuration.nix
          ({
            inputs,
            pkgs,
            ...
          }: {
            home-manager = {
              extraSpecialArgs = {inherit inputs;};
              users = {
                killua = import ./nixos/home-manager/home.nix;
              };
            };
          })
        ];
      };
    };

    darwinConfigurations = rec {
      macnix = darwinSystem {
        system = "aarch64-darwin";
        modules = [
          homemanager.darwinModules.home-manager
          ./macnix/packages/nix-index.nix
          ./macnix/settings.nix
          ./macnix/brew.nix
          ./macnix/packages
          ./macnix
        ];
      };
    };

    homeManagerConfigurations = {
      archnix = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          nixgl = nixgl;
        };
        modules = [
          nix-flatpak.homeManagerModules.nix-flatpak
          inputs.vicinae.homeManagerModules.default
          inputs.nixCats.homeModule
          ({
            pkgs,
            lib,
            inputs,
            ...
          }: {
            imports = attrValues self.homeManagerModules ++ [
            ./archnix/home.nix
            inputs.dms.homeModules.dankMaterialShell.default
            ];
            nixpkgs = {
              overlays =
                [
                  nur.overlays.default
                  nixgl.overlay
                ];
              config = {
                allowUnfree = true;
              };
            };
          })
        ];
      };
    };
  };
}
