{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixpkgs-22.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-stable.url = "github:NixOS/nixpkgs/nixos-22.05";

    home-manager = {
      url = "github:rycee/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
      neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
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


    mach-nix.url = "github:DavHau/mach-nix";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-utils.url = "github:numtide/flake-utils";
    mk-darwin-system.url = "github:vic/mk-darwin-system/main";
    spacebar.url = "github:cmacrae/spacebar/v1.3.0";
  };

  outputs = { self, darwin, home-manager, flake-utils, nixpkgs, neovim-nightly, nur, emacs, mach-nix, ... }@inputs:
    let
      # Some building blocks ------------------------------------------------------------------- {{{

      inherit (darwin.lib) darwinSystem;
      inherit (inputs.nixpkgs-unstable.lib) attrValues makeOverridable optionalAttrs singleton;

      # Configuration for `nixpkgs`
      nixpkgsConfig = {
        config = { allowUnfree = true; };
        overlays = attrValues self.overlays ++ singleton (
          # Sub in x86 version of packages that don't build on Apple Silicon yet
          final: prev: (optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
            inherit (final.pkgs-x86)
              idris2;
          })
        );
      };

      homeManagerStateVersion = "22.05";

      primaryUserInfo = {
        username = "killua";
        fullName = "Akshay Bhat";
        email = "bhat7362@gmail.com";
        nixConfigDirectory = "/Users/killua/.config/nixpkgs";
      };

      # Modules shared by most `nix-darwin` personal configurations.
      nixDarwinCommonModules = attrValues self.darwinModules ++ [
        # `home-manager` module
        home-manager.darwinModules.home-manager
        (
          { config, ... }:
          let
            inherit (config.users) primaryUser;
          in
          {
            nixpkgs = nixpkgsConfig;
            # Hack to support legacy worklows that use `<nixpkgs>` etc.
            # nix.nixPath = { nixpkgs = "${primaryUser.nixConfigDirectory}/nixpkgs.nix"; };
            nix.nixPath = { nixpkgs = "${inputs.nixpkgs-master}"; };
            # `home-manager` config
            users.users.${primaryUser.username}.home = "/Users/${primaryUser.username}";
            home-manager.useGlobalPkgs = true;
            home-manager.users.${primaryUser.username} = {
              imports = attrValues self.homeManagerModules;
              home.stateVersion = homeManagerStateVersion;
              home.user-info = config.users.primaryUser;
            };
            # Add a registry entry for this flake
            nix.registry.my.flake = self;
          }
        )
      ];
      # }}}
    in
    {

      # System outputs ------------------------------------------------------------------------- {{{

      # My `nix-darwin` configs
      darwinConfigurations = rec {
        # Mininal configurations to bootstrap systems
        bootstrap-x86 = makeOverridable darwinSystem {
          system = "x86_64-darwin";
          modules = [
             { nixpkgs = nixpkgsConfig; 
               services.nix-daemon.enable = true;
               } 
             ];
        };
        bootstrap-arm = bootstrap-x86.override { system = "aarch64-darwin"; };

        # My Apple Silicon macOS laptop config
        macnix = darwinSystem {
          system = "aarch64-darwin";
          modules = nixDarwinCommonModules ++ [
            {
              users.primaryUser = primaryUserInfo;
              networking.computerName = "killua";
              networking.hostName = "killua";
              networking.knownNetworkServices = [
                "Wi-Fi"
                "USB 10/100 LAN"
              ];
            }
          ];
        };
      };

      # Config I use with Linux cloud VMs
      # Build and activate with `nix build .#archnix.activationPackage; ./result/activate`


            archnix = home-manager.lib.homeManagerConfiguration {
          configuration = { pkgs, lib, ... }:
            {
              imports = [ ./homemanager/home.nix ];
	      nixpkgs = {
                overlays = [
                  neovim-nightly.overlay
                  nur.overlay
                  self.overlay
                  emacs.overlay
                  self.overrides
		  (final: prev: {
                    comma = import inputs.comma { pkgs = nixpkgs.legacyPackages."${prev.system}"; };
                    mach-nix = inputs.mach-nix.packages.${prev.system}.mach-nix;
                  })
                ];
		config = { allowUnfree = true; 
  cudaSupport = false;
  keep-derivations = true;
  keep-outputs = true;
};
              };
            };
          system = "x86_64-linux";
          homeDirectory = "/home/killua";
          username = "killua";

        };



      overlays = {
        # Overlays to add different versions `nixpkgs` into package set
        pkgs-master = final: prev: {
          pkgs-master = import inputs.nixpkgs-master {
            inherit (prev.stdenv) system;
            inherit (nixpkgsConfig) config;
          };
          # TODO: Remove when version 0.25.1 hits `nixpkgs-unstable`
          kitty = final.pkgs-master.kitty.overrideAttrs(_: {
            doInstallCheck = false;
          });
        };
        pkgs-stable = _: prev: {
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit (prev.stdenv) system;
            inherit (nixpkgsConfig) config;
          };
        };
        pkgs-unstable = _: prev: {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit (prev.stdenv) system;
            inherit (nixpkgsConfig) config;
          };
        };

        prefmanager = _: prev: {
          prefmanager = inputs.prefmanager.packages.${prev.stdenv.system}.default;
        };

        # Overlay that adds various additional utility functions to `vimUtils`
      #  vimUtils = import ./overlays/vimUtils.nix;

        # Overlay that adds some additional Neovim plugins
       # vimPlugins = final: prev:
        #  let
        #    inherit (self.overlays.vimUtils final prev) vimUtils;
        #  in
        #  {
        #    vimPlugins = prev.vimPlugins.extend (_: _:
        #      vimUtils.buildVimPluginsFromFlakeInputs inputs [
        #        # Add plugins here
        #      ]
       #     );
       #   };

        # Overlay useful on Macs with Apple Silicon
        apple-silicon = _: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Add access to x86 packages system is running Apple Silicon
          pkgs-x86 = import inputs.nixpkgs-unstable {
            system = "x86_64-darwin";
            inherit (nixpkgsConfig) config;
          };
        };

        # Overlay to include node packages listed in `./pkgs/node-packages/package.json`
        # Run `nix run my#nodePackages.node2nix -- -14` to update packages.
      #  nodePackages = _: prev: {
     #     nodePackages = prev.nodePackages // import ./pkgs/node-packages { pkgs = prev; };
     #   };

        # Overlay that adds `lib.colors` to reference colors elsewhere in system configs
       # colors = import ./overlays/colors.nix;
      };

      darwinModules = {
        # My configurations
     #   malo-bootstrap = import ./darwin/bootstrap.nix;
     #   malo-defaults = import ./darwin/defaults.nix;
      #  malo-general = import ./darwin/general.nix;
      #  malo-homebrew = import ./darwin/homebrew.nix;

        # Modules I've created
       # programs-nix-index = import ./modules/darwin/programs/nix-index.nix;
       # security-pam = import ./modules/darwin/security/pam.nix;
       # users-primaryUser = import ./modules/darwin/users.nix;
      };

      homeManagerModules = {
        # My configurations
     #   malo-config-files = import ./home/config-files.nix;
     #   malo-fish = import ./home/fish.nix;
     #   malo-git = import ./home/git.nix;
     #   malo-git-aliases = import ./home/git-aliases.nix;
     #   malo-gh-aliases = import ./home/gh-aliases.nix;
     #   malo-kitty = import ./home/kitty.nix;
     #   malo-neovim = import ./home/neovim.nix;
     #   malo-packages = import ./home/packages.nix;
     #   malo-starship = import ./home/starship.nix;
     #   malo-starship-symbols = import ./home/starship-symbols.nix;

        # Modules I've created
      #  programs-neovim-extras = import ./modules/home/programs/neovim/extras.nix;
      #  programs-kitty-extras = import ./modules/home/programs/kitty/extras.nix;
      #  home-user-info = { lib, ... }: {
      #    options.home.user-info =
     #       (self.darwinModules.users-primaryUser { inherit lib; }).options.users.primaryUser;
    #    };
      };
      # }}}

      # Add re-export `nixpkgs` packages with overlays.
      # This is handy in combination with `nix registry add my /Users/malo/.config/nixpkgs`
    } // flake-utils.lib.eachDefaultSystem (system: {
      legacyPackages = import inputs.nixpkgs-unstable {
        inherit system;
        inherit (nixpkgsConfig) config;
        overlays = with self.overlays; [
          pkgs-master
          pkgs-stable
          apple-silicon
      #    nodePackages
        ];
      };
    });
}