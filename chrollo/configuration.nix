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
    inputs.sops-nix.nixosModules.sops
    ../modules/common/sops-system.nix
    ../modules/containers
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
        # Enables BlueZ Experimental ISO socket — required for LE Audio (BAP/LC3)
        KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
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

  # Pin the kernel to the rev that produced the currently-activated
  # /nix/store/...-linux-6.12.67 derivation, so the cached virtualbox
  # kernel modules (virtualbox-modules-7.2.4-6.12.67) keep applying
  # without a rebuild against a newer kernel.
  boot.kernelPackages =
    (import inputs.nixpkgs-kernel {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    })
    .linuxPackages;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraUpFlags = ["--accept-dns=false"]; # Disable Tailscale DNS override
  };
  services.flatpak.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  programs.openvpn3.enable = true;

  hardware.graphics = {
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

  networking.hostName = "chrollo";
  networking.networkmanager = {
    enable = true;
    # dns = "systemd-resolved"; # Use resolved for DNS
  };

  # networking.nameservers = [
  #   "1.1.1.1"
  #   "1.0.0.1"
  # ];

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "true";
      Domains = ["~."];
      FallbackDNS = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      DNSOverTLS = "true";
    };
  };
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
  # Re-enabled for boeingvpn (zsh function uses openconnect --protocol=gp).
  # Pulls in webkitgtk (long compile).
  networking.networkmanager.plugins = [pkgs.networkmanager-openconnect];

  # networking.resolvconf.dnsExtensionMechanism = false;
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

  services.libinput.enable = true;

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
    openconnect
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
      # Allow non-root users to use the substituters declared in flake.nix's
      # nixConfig (otherwise the daemon silently drops them and rebuilds from
      # source — e.g. yt-dlp pulling in deno from chaotic-nyx).
      trusted-users = ["root" "@wheel"];
      # Mirror flake.nix nixConfig at the daemon level so every user gets the
      # caches without --accept-flake-config and without trusted-user gating.
      substituters = [
        "https://cache.nixos.org/"
        "https://hyprland.cachix.org"
        "https://vicinae.cachix.org"
        "https://nix-community.cachix.org"
        "https://chaotic-nyx.cachix.org"
        "https://yazi.cachix.org"
        "https://attic.xuyh0120.win/lantian"
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
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
    libx11
    libxext
    libxi
    libxrender
    libxtst
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

  boot.blacklistedKernelModules = ["kvm_intel" "kvm"];

  services.dbus.packages = [pkgs.blueman pkgs.openvpn3];
  services.udev.packages = [pkgs.vial];
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
