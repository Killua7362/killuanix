{ config, pkgs, ... }:

let
  libDir = "/home/killua/steamlib";
in
{
  home.packages = with pkgs; [
    (writeScriptBin "steam" ''
      #!${stdenv.shell}
      HOME="${libDir}" exec ${steam}/bin/steam "$@"
    '')
 
#    lutris
   mangohud
    protontricks
    openssl
    nur.repos.metadark.vkBasalt
    nur.repos.metadark.goverlay
    rocm-opencl-icd 
    rocm-opencl-runtime 
];
   home.activation.setupSteamDir = ''mkdir -p "${libDir}"'';
  # better for steam proton games
#  systemd.extraConfig = "DefaultLimitNOFILE=1048576";

}
