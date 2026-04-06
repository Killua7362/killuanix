# CachyOS Handheld Settings ported to NixOS
# Sources:
#   - CachyOS-Handheld-main/usr/lib/sysctl.d/20-steamos-customizations.conf
#   - CachyOS-Handheld-main/usr/lib/modprobe.d/blacklist-handheld.conf
#   - CachyOS-Handheld-main/usr/lib/modules-load.d/hid-preload.conf
#   - CachyOS-Handheld-main/etc/security/limits.d/memlock.conf
#   - CachyOS-Handheld-main/etc/systemd/logind.conf.d/steam-deckify.conf
#   - CachyOS-Handheld-main/usr/share/pipewire/pipewire.conf.d/10-min-quant.conf
#   - CachyOS-Handheld-main/usr/share/cachyos-handheld/msi-claw/wireplumber/alsa-card0.conf
#   - CachyOS-Handheld-main/usr/share/cachyos-handheld/common/wireplumber/alsa-card1.conf
#   - CachyOS-Handheld-main/usr/lib/udev/rules.d/70-led-control.rules
#   - CachyOS-Handheld-main/etc/xdg/*
#   - CachyOS chwd profiles/pci/handhelds/profiles.toml (MSI Claw Intel)
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ══════════════════════════════════════════════════════════════
  # Sysctl tuning
  # ══════════════════════════════════════════════════════════════
  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # Optimized for ZRAM swap
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_bytes" = 268435456;
    "vm.compaction_proactiveness" = 0; # Reduce latency spikes during gaming
    "vm.max_map_count" = 2147483642; # Required by many Steam/Proton games
    "kernel.nmi_watchdog" = 0; # Power savings
    "fs.file-max" = 2097152;
    "net.ipv4.tcp_fin_timeout" = 5; # Quick TCP port reuse for games
    "dev.i915.perf_stream_paranoid" = 0; # GPU perf counter access
  };

  # ══════════════════════════════════════════════════════════════
  # Kernel parameters
  # ══════════════════════════════════════════════════════════════
  boot.kernelParams = [
    "audit=0"
    "log_buf_len=4M"
    "transparent_hugepage=always" # Gaming performance
    "mem_sleep_default=s2idle" # Meteor Lake uses S0ix (no S3)
    "usbcore.autosuspend=-1" # Disable USB autosuspend — prevents mice/keyboards from disconnecting when idle
  ];

  # ══════════════════════════════════════════════════════════════
  # Kernel modules
  # ══════════════════════════════════════════════════════════════
  # Blacklist watchdog timer (from blacklist-handheld.conf)
  boot.blacklistedKernelModules = ["wdat_wdt"];

  # Preload HID drivers to prevent Steam evdev fallback race (from hid-preload.conf)
  # Load msi-wmi-platform for MSI Claw (from CachyOS chwd MSI Claw profile)
  boot.kernelModules = [
    "hid_nintendo"
    "hid_playstation"
    "xpad" # MSI Claw controller (Linux 6.12+)
    "msi-wmi-platform" # MSI Claw platform driver
  ];

  # ══════════════════════════════════════════════════════════════
  # ZRAM swap (from CachyOS)
  # ══════════════════════════════════════════════════════════════
  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  # ══════════════════════════════════════════════════════════════
  # Security limits — memlock for gaming/audio (from memlock.conf)
  # ══════════════════════════════════════════════════════════════
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "hard";
      item = "memlock";
      value = "2147484";
    }
    {
      domain = "*";
      type = "soft";
      item = "memlock";
      value = "2147484";
    }
  ];

  # ══════════════════════════════════════════════════════════════
  # Logind — power button (from steam-deckify.conf)
  # ══════════════════════════════════════════════════════════════
  services.logind.settings.Login ={
    HandleLidSwitch = "ignore";
    KillUserProcesses = true;
  };

  # ══════════════════════════════════════════════════════════════
  # PipeWire min-quantum (from 10-min-quant.conf)
  # ══════════════════════════════════════════════════════════════

  services.pipewire.extraConfig.pipewire."10-min-quant".text = ''
      context.properties = {
        default.clock.min-quantum = 256
      }
  '';

  # ══════════════════════════════════════════════════════════════
  # MSI Claw audio fix — increased ALSA headroom (from msi-claw/wireplumber/alsa-card0.conf)
  # Fixes audio cutting out issue
  # ══════════════════════════════════════════════════════════════
  environment.etc."wireplumber/wireplumber.conf.d/50-msiclaw-alsa.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          {
            node.name = "~alsa_output.pci-0000_00_1f.3*"
          }
        ]
        actions = {
          update-props = {
            api.alsa.headroom = 1024
          }
        }
      }
    ]
  '';

  # Common handheld audio config (from common/wireplumber/alsa-card1.conf)
  environment.etc."wireplumber/wireplumber.conf.d/50-handheld-common-alsa.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          {
            node.name = "~alsa_input.*"
            alsa.card_name = "sof-nau8821-max"
          }
          {
            node.name = "~alsa_output.*"
            alsa.card_name = "sof-nau8821-max"
          }
        ]
        actions = {
          update-props = {
            session.suspend-timeout-seconds = 0
            api.alsa.headroom = 1024
          }
        }
      }
    ]
  '';

  # ══════════════════════════════════════════════════════════════
  # LED control udev rules (from 70-led-control.rules)
  # ══════════════════════════════════════════════════════════════
  services.udev.extraRules = ''
    # LED color/brightness write access for user
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/brightness'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/effect'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/enabled'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/mode'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/multi_intensity'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/profile'"
    SUBSYSTEM=="leds", RUN+="${pkgs.coreutils}/bin/chown 1000:1000 '/sys/class/leds/%k/speed'"

    # Controller support — uinput access for HHD controller emulation
    KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"

    # MSI Claw HID device access (vendor ID 0db0)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0db0", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0db0", MODE="0660", TAG+="uaccess"
  '';

  # ══════════════════════════════════════════════════════════════
  # KDE / Plasma handheld configs (from CachyOS etc/xdg/*)
  # ══════════════════════════════════════════════════════════════

  # Flat pointer acceleration (from kcminputrc)
  environment.etc."xdg/kcminputrc".text = ''
    [Libinput][Defaults]
    PointerAccelerationProfile=1
  '';

  # Virtual keyboard + Xwayland EIS (from kwinrc)
  environment.etc."xdg/kwinrc".text = ''
    [Wayland]
    InputMethod[$e]=/usr/share/applications/org.kde.plasma.keyboard.desktop
    VirtualKeyboardEnabled=true
    [Xwayland]
    XwaylandEisNoPrompt=true
  '';

  # Power management for handheld (from powerdevilrc)
  environment.etc."xdg/powerdevilrc".text = ''
    [AC][Display]
    LockBeforeTurnOffDisplay=true

    [AC][SuspendAndShutdown]
    AutoSuspendAction=0
    PowerButtonAction=1

    [Battery][Display]
    DimDisplayIdleTimeoutSec=60
    LockBeforeTurnOffDisplay=true
    TurnOffDisplayIdleTimeoutSec=60

    [Battery][SuspendAndShutdown]
    AutoSuspendIdleTimeoutSec=300
    PowerButtonAction=1

    [LowBattery][Display]
    LockBeforeTurnOffDisplay=true
    TurnOffDisplayIdleTimeoutSec=60

    [LowBattery][SuspendAndShutdown]
    PowerButtonAction=1
  '';

  # Vapor theme, disable single-click (from kdeglobals)
  environment.etc."xdg/kdeglobals".text = ''
    [KDE]
    LookAndFeelPackage=com.valve.vapor.desktop
    SingleClick=false

    [KDE Action Restrictions][$i]
    action/switch_user=false
    action/start_new_session=false
    action/lock_screen=false

    [KDE Control Module Restrictions][$i]
    kcm_plasmalogin=false

    [Desktop Entry]
    DefaultProfile=Vapor.profile
  '';
}
