{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    mach-nix.url = "github:DavHau/mach-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self,flake-utils, home-manager, nixpkgs, neovim-nightly, nur, emacs, mach-nix, ... }@inputs:
    {
      homeManagerConfigurations = {
        killua = inputs.home-manager.lib.homeManagerConfiguration {
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
      };
      overlay = import ./Extern/overlays;
      overrides = import ./Extern/overrides;

    };
}
