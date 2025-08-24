{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
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
  };

  outputs =
    inputs @ {
       self
    , flake-utils
    , home-manager
    , nixpkgs
    , neovim-nightly-overlay
    , nur
    , emacs
    , darwin
    , mk-darwin-system
    , nixgl
    , ...
    }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (inputs.nixpkgs-unstable.lib)
        attrValues makeOverridable optionalAttrs singleton;
      nixpkgsConfig = {
        config = {
          allowUnfree = true;
          allowBroken = true;
            /* allowUnsupportedSystem = true; */
            };
          overlays = attrValues self.overlays ++ singleton (final: prev:
            (optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
              inherit (final.pkgs-x86) idris2;
            }));
        };

        nixDarwinCommonModules = attrValues self.darwinModules ++ [
          home-manager.darwinModules.home-manager
          ({ config, ... }: {
            nixpkgs = nixpkgsConfig;
            nix.nixPath = { nixpkgs = "${inputs.nixpkgs-unstable}"; };
            users.users."killua" = {
              home = "/Users/killua";
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users."killua" = {
              imports = attrValues self.commonhomeModules ++ [
                ./macnix/home.nix
              ];
            };
          })
        ];

        homeManagerConfigurations = {
          archnix = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
            extraSpecialArgs = {
            inherit inputs;
            nixgl = nixgl;
          };
            modules = [
              {
                home = {
                  username = "killua";
                  homeDirectory = "/home/killua";
                  stateVersion = "24.11";
                };
              }
              ({ pkgs, lib,inputs, ... }: {
              
                imports = attrValues self.commonhomeModules ++ [ ./archnix/home.nix ];
                nixpkgs = {
                  overlays = attrValues self.overlays ++ [
                    # neovim-nightly.overlays.default
                    nur.overlays.default
                    emacs.overlay
                    nixgl.overlay
                  ];
                  config = {
                    allowUnfree = true;
                    cudaSupport = false;
                    keep-derivations = true;
                    keep-outputs = true;
                  };
                };
              })
            ];
          };
        };
        in
        {
        darwinConfigurations = rec {
          macnix = darwinSystem {
            system = "aarch64-darwin";
            modules = nixDarwinCommonModules ++ [
              ##./macnix/packages/pam.nix
              ./macnix/packages/nix-index.nix
              ./macnix/settings.nix
              ./macnix/brew.nix

              ({ pkgs, lib, ... }: {
                nix = {
                  extraOptions = ''
                    system = aarch64-darwin
                    extra-platforms = aarch64-darwin x86_64-darwin
                    experimental-features = nix-command flakes
                    build-users-group = nixbld
                  '';
                };
                environment.systemPackages = with pkgs; [
                  wget
                  eza
                  nixfmt-classic
                  niv
                ];
              })

              {
                networking.computerName = "killua";
                networking.hostName = "killua";
                networking.knownNetworkServices = [ "Wi-Fi" "USB 10/100 LAN" ];
              }
            ];
          };
        };

        inherit homeManagerConfigurations;
        
        overlays = {

          pkgs-master = final: prev: {
            pkgs-master = import inputs.nixpkgs-master {
              inherit (prev.stdenv) system;
              inherit (nixpkgsConfig) config;
            };
          };

          pkgs-stable = final: prev: {
            pkgs-stable = import inputs.nixpkgs-stable {
              inherit (prev.stdenv) system;
              inherit (nixpkgsConfig) config;
            };
          };
          pkgs-unstable = final: prev: {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit (prev.stdenv) system;
              inherit (nixpkgsConfig) config;
            };
          };

          prefmanager = _: prev: {
            prefmanager =
              inputs.prefmanager.packages.${prev.stdenv.system}.default;
          };

          # Overlay useful on Macs with Apple Silicon
          apple-silicon = _: prev:
            optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
              # Add access to x86 packages system is running Apple Silicon
              pkgs-x86 = import inputs.nixpkgs-unstable {
                system = "x86_64-darwin";
                inherit (nixpkgsConfig) config;
              };
            };

        };

        darwinModules = { };

        commonhomeModules = {
          git = import ./common/git.nix;
          packages = import ./common/packages.nix;
          zsh = import ./common/zsh.nix;
        };


      };

      }
