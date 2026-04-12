{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  session = {
    command = "${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop";
    user = "killua";
  };
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    ../modules/containers/quadlet.nix
    ../modules/vms/system.nix
  ];

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = ["8.8.8.8" "8.8.4.4"];
    };
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = false; # docker is already enabled
    defaultNetwork.settings.dns_enabled = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  services.blueman.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraUpFlags = ["--accept-dns=false"]; # Disable Tailscale DNS override
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
    trustedInterfaces = ["tailscale0" "docker0" "virbr0"];
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
    dns = "systemd-resolved"; # Use resolved for DNS
  };

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = ["~."];
    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    dnsovertls = "true";
  };
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
  #networking.networkmanager.plugins = [ "openconnect" ];
  networking.networkmanager.plugins = [pkgs.networkmanager-openconnect];

  networking.resolvconf.dnsExtensionMechanism = false;
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

    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire-pulse."30-network-tcp" = {
      "pulse.cmd" = [
        {
          cmd = "load-module";
          args = "module-native-protocol-tcp port=4713 auth-anonymous=1 listen=0.0.0.0";
        }
      ];
    };
  };

  services.xserver.libinput.enable = true;

  users.users.killua = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = inputs.self.commonModules.user.userConfig.sshKeys;
    description = "killua";
    extraGroups = ["networkmanager" "wheel" "openvpn" "docker" "audio" "libvirtd"];
    shell = pkgs.zsh;
    linger = true;
    autoSubUidGidRange = true;
  };

  programs.java = {
    enable = true;
    package = pkgs.zulu8;
  };

  environment.systemPackages = with pkgs; [
    bluez-tools
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
    ocproxy
    hubstaff
    distrobox
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
      pulseaudio = true;
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

  programs.zsh.enable = true;

  # programs.fish.enable = true;
  # programs.bash = {
  #   interactiveShellInit = ''
  #     if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
  #     then
  #       shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
  #       exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
  #     fi
  #   '';
  # };

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

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];

  virtualisation.quadlet.enable = true;
  boot.blacklistedKernelModules = ["kvm_intel" "kvm"];

  services.dbus.packages = [pkgs.blueman pkgs.openvpn3];
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };

  xdg.portal = {
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      # xdg-desktop-portal-kde    # Uncomment if KDE Plasma doesn't provide its own
    ];

    config = {
      common = {
        default = ["gtk"];
      };
      hyprland = {
        default = ["gtk" "hyprland"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      };
      kde = {
        default = ["kde" "gtk"];
      };
    };
  };

  #    services.greetd = {
  #    enable = true;
  #    settings = {
  #      terminal.vt = 1;
  #      default_session = session;
  #      initial_session = session;
  #    };
  #  };
  #  programs.regreet.enable = true;
}
