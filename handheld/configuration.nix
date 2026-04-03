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
    ./gaming.nix
    ./wifi-fix.nix
    ./boot.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # ── CachyOS Deckify Kernel (BORE scheduler, handheld patches, RCU_LAZY) ──
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-deckify;

  # ── Networking ──
  networking.hostName = "handheld";
  networking.networkmanager.enable = true;

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
  hardware.pulseaudio.enable = false;
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
  };

  # ── Bluetooth ──
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
  services.blueman.enable = true;

  # ── User ──
  users.users.killua = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = inputs.self.commonModules.user.userConfig.sshKeys;
    description = "killua";
    extraGroups = ["networkmanager" "wheel" "audio" "input" "video"];
    shell = pkgs.zsh;
    linger = true;
  };
  programs.zsh.enable = true;

  # ── Scheduler: scx_lavd (latency-aware, optimized for handhelds) ──
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

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
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [41641];
  };

  # ── Packages ──
  environment.systemPackages = with pkgs; [
    git
    bluez-tools
    moonlight-qt
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

  # ── Nix settings ──
  nixpkgs.config.allowUnfree = true;
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

  system.stateVersion = "25.11";
}
