# DroidCam system side (phone-as-webcam/mic).
#
# The `droidcam` client itself is a Home Manager package (desktopPackages in
# modules/common/packages.nix) — it only *writes into* devices it cannot
# create. Those devices are kernel-level, hence this module:
#
#   v4l2loopback  → the fake /dev/video9 that browsers/Zoom read from
#   snd-aloop     → the ALSA loopback the phone's mic is piped into
#
# Imported by chrollo/configuration.nix and killua/configuration.nix.
{
  config,
  pkgs,
  ...
}: {
  # Out-of-tree module, so it builds against whatever kernel the host runs
  # (chrollo: main nixpkgs linuxPackages; killua: cachyos-deckify). On killua
  # this compiles locally — the cachyos kernel has no cached v4l2loopback
  # build upstream.
  boot.extraModulePackages = [config.boot.kernelPackages.v4l2loopback];

  boot.kernelModules = ["v4l2loopback" "snd-aloop"];

  # exclusive_caps=1 is what makes Chrome/Firefox/Zoom actually *list* the
  # device (they ignore loopback nodes that advertise capture+output both).
  # video_nr is pinned to 9 so the node name is stable across reboots and
  # doesn't race the real UVC cameras for /dev/video0.
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=9 card_label="DroidCam" exclusive_caps=1
  '';

  # `video` for the loopback node. List-merges with the extraGroups already
  # set in each host's configuration.nix (killua already has it; chrollo
  # didn't).
  users.users.killua.extraGroups = ["video"];

  environment.systemPackages = [
    pkgs.v4l-utils # `v4l2-ctl --list-devices` to confirm the node exists
    # USB mode speaks adb to the phone (Wi-Fi mode doesn't need it).
    # `programs.adb.enable` was removed upstream — systemd 258 does the
    # uaccess rules itself, so the plain package is the whole story now.
    pkgs.android-tools
  ];
}
