# Intel Arc GPU Configuration for MSI Claw (Meteor Lake)
# Based on CachyOS chwd Intel profile + community research
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ── Xe driver (recommended over i915 for Meteor Lake, ~20% FPS boost) ──
  boot.initrd.kernelModules = ["xe"];
  boot.kernelParams = [
    "xe.force_probe=7d55" # Force Xe driver for Meteor Lake iGPU
    "i915.force_probe=!7d55" # Prevent i915 from claiming the GPU
    "fbcon=rotate:1" # Console rotation for portrait-native panel
  ];

  # ── Intel firmware (GuC, HuC, DMC) ──
  hardware.enableRedistributableFirmware = true;

  # ── Graphics stack (from CachyOS Intel profile) ──
  # Equivalent of: mesa, lib32-mesa, vulkan-intel, lib32-vulkan-intel,
  #   intel-media-driver, vpl-gpu-rt, opencl-mesa, gst-plugin-va
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit Vulkan/Mesa for Proton/Wine
    extraPackages = with pkgs; [
      intel-media-driver # VA-API (iHD driver)
      vpl-gpu-rt # Intel Quick Sync Video
      intel-compute-runtime # OpenCL
      gst_all_1.gst-vaapi # GStreamer VA-API plugin
    ];
  };

  # ── Environment variables ──
  environment.sessionVariables = {
    # Essential: fixes gamescope color corruption on Intel Arc
    INTEL_DEBUG = "noccs";
    # Modern VA-API driver
    LIBVA_DRIVER_NAME = "iHD";
    # Expose async compute queue for Vulkan (ANV)
    ANV_QUEUE_OVERRIDE = "gc=2,c=1";
    # Enable compute engine on Arc
    INTEL_COMPUTE_CLASS = "1";
    # Force Mesa Rusticl OpenCL instead of stub (from CachyOS Intel post_install)
    RUSTICL_ENABLE = "iris";
  };

  # ── Backlight control ──
  services.udev.extraRules = ''
    # Enable brightness control for unprivileged users (Steam UI slider)
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod a+w /sys/class/backlight/%k/brightness"
  '';

  # ── Display rotation for 7" portrait-native panel ──
  environment.etc."X11/xorg.conf.d/90-jovian-msiclaw.conf".text = ''
    Section "Monitor"
      Identifier     "eDP-1"
      Option         "Rotate"    "right"
    EndSection

    Section "InputClass"
      Identifier "MSI Claw touch screen"
      MatchIsTouchscreen "on"
      MatchDevicePath    "/dev/input/event*"
      MatchDriver        "libinput"
      # 90° clockwise rotation matrix
      Option "TransformationMatrix" "0 1 0 -1 0 1 0 0 1"
    EndSection
  '';
}
