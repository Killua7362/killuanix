{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.portainer-on-nixos.nixosModules.portainer
  ];
virtualisation.docker = {
  enable = true;
  rootless = {
    enable = true;
    setSocketVariable = true;
  };
};

          services.portainer = {
            enable = true; # Default false

            version = "latest"; # Default latest, you can check dockerhub for
                                # other tags.

            openFirewall = true; # Default false, set to 'true' if you want
                                    # to be able to access via the port on
                                    # something other than localhost.

            port = 9443; # Sets the port number in both the firewall and
                         # the docker container port mapping itself.
          };


hardware.bluetooth.enable = true;
#  hardware.pulseaudio.enable = true;
services.blueman.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraUpFlags = [ "--accept-dns=false" ];  # Disable Tailscale DNS override
  };
  #  services.flatpak.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  programs.openvpn3.enable = true;

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver
    ];
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [41641 21116 1194];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedTCPPorts = [443];
    allowedTCPPortRanges = [
      {
        from = 21114;
        to = 21119;
      }
      {
        from = 1714;
        to = 1764;
      }
    ];
  };

networking.hostName = "killua";
networking.networkmanager = {
  enable = true;
  dns = "systemd-resolved";  # Use resolved for DNS
};

services.resolved = {
  enable = true;
  dnssec = "false";  # Optional, can cause issues with some networks
  fallbackDns = [ "8.8.8.8" "1.1.1.1" ];
};
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
#networking.networkmanager.plugins = [ "openconnect" ];
networking.networkmanager.packages = [ pkgs.networkmanager-openconnect ];


  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.xserver.libinput.enable = true;

  users.users.killua = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = inputs.self.commonModules.user.userConfig.sshKeys;
    description = "killua";
    extraGroups = ["networkmanager" "wheel" "openvpn" "docker"];
  };

    programs.java = {
      enable = true;
      package = pkgs.zulu8;
    };

  environment.systemPackages = with pkgs; [
    git
    moonlight-qt
    zulu8
#    javaPackages.compiler.openjdk8
#    jdk17_headless
#jdk21_headless
distrobox
docker-compose
#globalprotect-openconnect
#inputs.globalprotect-openconnect.packages.${pkgs.system}.default
  ];

  system.stateVersion = "25.11";

  services.openssh = {
    enable = true;
    settings = {
      PubkeyAuthentication = true;
      AllowUsers = ["killua"];
    };
  };

  nixpkgs = {
    overlays = [

    ];
    config = {
      allowUnfree = true;
     permittedInsecurePackages = [
                "qtwebengine-5.15.19"
              ];
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      nix-path = config.nix.nixPath;
    };
    channel.enable = false;
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  programs.fish.enable = true;
  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
      glib
      libGL
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXtst
      freetype
      fontconfig
      alsa-lib
      cups
    ];

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["killua"];
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.dragAndDrop = true;

  services.dbus.packages = [ pkgs.blueman pkgs.openvpn3 ];

}
