    let
      source = builtins.fromJSON (builtins.readFile ./awesome.json);
    in

(final: prev: {
  wine = prev.winePackages.staging;
       awesome-git = prev.awesome.overrideAttrs (old: {
          src = prev.fetchFromGitHub rec {
            name = "source-${owner}-${repo}-${rev}";
            inherit (source) owner repo rev sha256;
          };
        });
  
  wine64 = prev.wineWowPackages.staging;
  kmonad = prev.haskellPackages.callPackage ./kmonad.nix {};
  picom-git = (prev.picom.overrideAttrs (old: {
    src = prev.fetchFromGitHub {
      owner = "yshui";
      repo = "picom";
      rev = "7ba87598c177092a775d5e8e4393cb68518edaac";
      sha256 = "sha256-CaSw80lfxopVNydn9f6lbl28agzvMkDCub8dYRv3Q30=";
    };
  })).override { stdenv = prev.clangStdenv; };
})

