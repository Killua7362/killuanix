# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
 # additions = final: _prev: {
#
  #};

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };


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
}
