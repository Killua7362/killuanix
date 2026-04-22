# Pipewire pin overlay for the handheld.
#
# Replaces `pkgs.pipewire` with the version from `inputs.nixpkgs-pipewire`
# (a pre-1.6 nixpkgs rev) to work around a runtime LDAC init failure in
# pipewire 1.6.x on the Intel Lunar Lake BT controller.
#
# Symptoms before pin:
#   wireplumber: spa.bluez5.codecs.ldac: LDAC decoder initialization failed:
#     LDACBT_ERR_FATAL (268981248)
#   wireplumber: spa.bluez5.sink.media: codec LDAC initialization failed
# => A2DP silently falls back to SBC even though the device advertises LDAC.
#
# We only pin `pipewire` itself — wireplumber, bluez, and the rest stay on
# main nixpkgs. The pipewire derivation builds the bluez5 codec plugins
# (libspa-codec-bluez5-ldac.so etc.) in-tree, so pinning pipewire is
# sufficient to replace the broken plugin.
{inputs, ...}: final: prev: let
  pinned = import inputs.nixpkgs-pipewire {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in {
  pipewire = pinned.pipewire;
}
