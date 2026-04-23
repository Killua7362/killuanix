# Pipewire pin overlay for the killua host (MSI Claw).
#
# Narrow override: replaces only pipewire's `src` / `version` / `patches` with
# the pre-1.6 ones from `inputs.nixpkgs-pipewire`, while keeping all buildInputs
# (glibc, bluez, alsa, gst-plugins-base, …) from the current nixpkgs. This
# works around a runtime LDAC init failure in pipewire 1.6.x on the Intel
# Lunar Lake BT controller without dragging the pinned nixpkgs' entire
# transitive closure into the system.
#
# Symptoms before pin:
#   wireplumber: spa.bluez5.codecs.ldac: LDAC decoder initialization failed:
#     LDACBT_ERR_FATAL (268981248)
#   wireplumber: spa.bluez5.sink.media: codec LDAC initialization failed
# => A2DP silently falls back to SBC even though the device advertises LDAC.
#
# The bluez5 codec plugins (libspa-codec-bluez5-ldac.so etc.) are built from
# the pipewire tree in-tree; rebuilding pipewire from the pinned source is
# what regenerates the working codec. The pipewire↔codec ABI must match, so
# we can't cherry-pick only the codec .so — but we can avoid the pinned
# closure by swapping source rather than the whole package.
#
# Trade-off: pkgs.pipewire's output hash still changes, so anything in its
# reverse-dep graph (ffmpeg variants, kodi, thunderbird, yazi, etc.) will
# still rebuild locally since cache.nixos.org doesn't have them built against
# this pipewire. That's inherent to any pipewire deviation.
{inputs, ...}: final: prev: let
  pinned = import inputs.nixpkgs-pipewire {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Disable plugins whose 1.4.7 source no longer compiles against current
  # nixpkgs headers (libcamera API churn: FrameBuffer::planes() return type,
  # std::optional<string_view> handling). Handheld doesn't use these plugins,
  # so this is effectively free.
  disabledPlugins = ["libcamera"];
  patchFlag = f:
    let
      matches = prev.lib.findFirst (p: prev.lib.hasPrefix "-D${p}=" f) null disabledPlugins;
    in
      if matches == null then f else "-D${matches}=disabled";
in {
  pipewire = prev.pipewire.overrideAttrs (_: {
    # mesonFlags must come from the pinned side: meson options like `libsystemd`
    # were added in pipewire 1.6 and the 1.4.7 source rejects them.
    inherit (pinned.pipewire) version src patches;
    mesonFlags = map patchFlag pinned.pipewire.mesonFlags;
  });
}
