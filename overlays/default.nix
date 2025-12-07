{inputs, ...}: {
  modifications = final: prev: {
  };

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

  apple-silicon = _: prev:
    optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
      pkgs-x86 = import inputs.nixpkgs-unstable {
        system = "x86_64-darwin";
        inherit (nixpkgsConfig) config;
      };
    };
}
