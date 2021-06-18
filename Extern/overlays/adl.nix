{ lib, stdenv, fetchFromGitHub, pkgs, ... }:

stdenv.mkDerivation {
  name = "adl";

  src = fetchFromGitHub {
    owner = "RaitaroH";
    repo = "adl";
    rev = "7752e36f92cd6d6f00d4a7eccdde9cf141abb06e";
    sha256 = "MmVPh8edSw/h+3uvYbYHQLX/66pY5Yk0v/OCL7RayBE=";
  };

  buildInputs = with pkgs; [
    trackma
    anime-downloader
  ];

  phases = "installPhase";
  installPhase = ''
    mkdir -p $out/bin
    cp $src/adl $out/bin/adl
    cp ${pkgs.trackma}/bin/trackma $out/bin/trackma
    cp ${pkgs.anime-downloader}/bin/anime $out/bin/anime
  '';

  meta = {
    homepage = "https://github.com/RaitaroH/adl";
    description = "popcorn anime-downloader + trackma wrapper";
    license = lib.licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
