(final: prev: {
  adl = prev.callPackage ./adl.nix {
    inherit (prev) fetchurl;
  };
  anime-downloader = prev.callPackage ./anime-downloader.nix {
    inherit (prev);
  };
  spotify-adblock = prev.callPackage ./spotify-adblock.nix {
    inherit (prev) writeShellScriptBin spotify;
    spotify-adblock-linux = final.spotify-adblock-linux;
  };
  spotify-adblock-linux = prev.callPackage ./spotify-adblock-linux.nix {
    inherit (prev) fetchurl;
  };
  trackma = prev.callPackage ./trackma.nix {
    inherit (prev);
  };
   libinih = prev.callPackage ./libinih.nix { };
  gamemode = prev.callPackage ./gamemode.nix {
    #benettiiiii
    inherit (prev);
  };
})


