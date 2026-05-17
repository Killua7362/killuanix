# MSI Claw Handheld NixOS Configuration
# CachyOS Handheld settings + Intel Arc GPU + Handheld Daemon
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./intel-gpu.nix
    ./handheld-tweaks.nix
    ./hhd.nix
    ./gaming
    ./wifi-fix.nix
    ./boot.nix
    # ./bluez5-ldac-pin.nix  # disabled — main nixpkgs now ships pipewire 1.6.3 via `nix flake update`; re-enable if LDAC/mSBC regress on a future bump
    inputs.sops-nix.nixosModules.sops
    ../modules/common/sops-system.nix
    ../modules/containers
    ../modules/vms/system.nix
  ];

  # ── CachyOS BORE kernel, LTO + x86_64-v3 microarch ──
  # MSI Claw 8 AI+ is Intel Lunar Lake (Core Ultra Series 2 / Xe2). Lunar Lake
  # supports x86_64-v3 baseline (AVX2/BMI/FMA) but NOT AVX512, so -v4/-zen4
  # variants won't run. LTO + v3 = fastest variant compatible with this SoC.
  # Deckify (prior choice) was AMD Steam Deck targeted and embedded
  # amd_iommu=off / amdgpu.* in CONFIG_CMDLINE — wrong hw, sourced the
  # repeated freezes. Cached on lantian attic — no local compile.
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;

  # ── Virtualisation: Docker (rootful), Podman/Quadlet, libvirtd (no VirtualBox) ──
  # VirtualBox disabled here — Oracle DB 19c image runs under QEMU/KVM instead.
  # Dropping vbox kills the per-rebuild virtualbox-modules-<vbox>-<kernel>
  # source build (3-5 min, never on any public cache).
  vms.virtualbox.enable = false;


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

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # ── Networking ──
  networking.hostName = "killua";
  networking.networkmanager.enable = true;
  # Re-enabled for boeingvpn. Heads up: webkitgtk can't substitute from cache here
  # because the pipewire-pin overlay changes its closure, so it builds locally.
  networking.networkmanager.plugins = [pkgs.networkmanager-openconnect];

  # ── Locale / Timezone ──
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
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

  # ── Desktop: Plasma 6 + Hyprland ──
  # NOTE: SDDM is NOT enabled here — Jovian's autoStart handles SDDM + auto-login
  # Both Plasma and Hyprland are available as desktop sessions.
  # Change `defaultDesktop` in gaming.nix to set which one "Return to Desktop" goes to.
  services.xserver.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ── Audio: PipeWire ──
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

  # ── Bluetooth ──
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
        # Enables BlueZ Experimental ISO socket (LE Audio / BAP / LC3)
        # plus Jovian/SteamOS's own UUID — KernelExperimental accepts a
        # comma-separated list, mkForce to override Jovian's single value.
        KernelExperimental = lib.mkForce "6fbaf188-05e0-496a-9885-d6ddfdb4e03e,15c0a148-c273-11ea-b3de-0242ac130004";
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
  services.blueman.enable = true;
  services.udev.packages = [pkgs.vial];

  # Intel Lunar Lake BT controller drops the ACL link when HFP/SCO initializes,
  # symptom: "Unable to get Hands-Free Voice gateway SDP record: Host is down"
  # in bluetoothd logs + the bluez_card vanishing from pactl. Disabling USB
  # autosuspend on the BT adapter is the most commonly reported workaround.
  # If this doesn't help, revert this block and drop HFP from WP's roles list.
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=N
  '';

  # ── User ──
  users.users.killua = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = inputs.self.commonModules.user.userConfig.sshKeys;
    description = "killua";
    extraGroups = ["networkmanager" "wheel" "audio" "input" "video" "docker" "libvirtd"];
    shell = pkgs.zsh;
    linger = true;
    autoSubUidGidRange = true;
  };
  programs.zsh.enable = true;

  # ── Scheduler: scx_lavd (latency-aware, optimized for handhelds) ──
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  # ── Flatpak ──
  services.flatpak.enable = true;

  # ── Thermal / Power management ──
  services.thermald.enable = true;
  # NOTE: powertop removed — it aggressively enables USB autosuspend which
  # kills mice/keyboards when idle. thermald + scx_lavd handle power fine.
  services.earlyoom.enable = true;

  # ── SSH ──
  services.openssh = {
    enable = true;
    settings = {
      PubkeyAuthentication = true;
      AllowUsers = ["killua"];
    };
  };

  # ── Tailscale ──
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # ── Firewall ──
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0" "docker0" "virbr0"];
    allowedUDPPorts = [41641];
  };

  # ── Packages ──
  environment.systemPackages = with pkgs; [
    git
    bluez-tools
    moonlight-qt
    ocproxy
    hubstaff
    distrobox
    docker-compose
  ];

  # ── Fonts ──
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];

  # ── nix-ld ──
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

  # ── Nix settings ──
  nixpkgs.config.allowUnfree = true;
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

  system.stateVersion = "25.11";
}
