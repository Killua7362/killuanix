# Runtime pipewire-bluez5 swap for the killua (MSI Claw) host.
#
# The pipewire 1.6.2 build in current nixpkgs has two bluez5 bugs that
# both bite this host (Intel Lunar Lake BT controller, CMF Buds Pro 2):
#
#   1. libldac-dec ldacBT_init_handle_decode() passes uninitialised
#      struct members to ldaclib_set_config_info(), so LDAC negotiation
#      logs "LDAC decoder initialization failed: LDACBT_ERR_FATAL
#      (268981248)" and A2DP collapses to SBC.
#
#   2. libspa-bluez5.so SEGVs inside spa_bt_device_supports_media_codec()
#      → get_features() → do_match() → regcomp() when wireplumber
#      enumerates the device's supported codecs (i.e. as soon as you
#      pick LDAC in the codec selector). Wireplumber dies, only CVSD is
#      left until you restart it. Fixed upstream by pipewire commit
#      99f901d "bluez5: fix spa_bt_device_supports_media_codec() for
#      HFP codecs", landed in 1.6.3.
#
# Why this approach:
#   - Bumping nixpkgs.pipewire to 1.6.3 cascades rebuilds of every
#     pipewire consumer (ffmpeg via sdl3, gtk4 via gst-plugins-bad,
#     electron, openal-soft, …) since none of those will substitute
#     against a different pipewire derivation hash. Hours of CPU.
#   - Patching just libldac-dec doesn't fix bug 2 and the libldac-dec
#     buildtime-input change still cascades.
#   - 1.4.7 codec swap is a non-starter — pipewire bumped the SPA
#     codec ABI from 12 to 16 between 1.4.x and 1.6.x, the older .so
#     gets rejected ("incompatible ABI version (12 != 16)") and
#     wireplumber crashes during plugin load.
#
# Approach: leave pkgs.pipewire untouched, swap only the bluez5/
# subdirectory of the SPA plugin tree at runtime, sourced from a
# cache-substituted pipewire 1.6.3 (input nixpkgs-pipewire). The
# entire bluez5/ directory is taken as a unit so libspa-bluez5.so and
# its codec plugins stay self-consistent at version 1.6.3
# (SPA_VERSION_BLUEZ5_CODEC_MEDIA = 16 in both 1.6.2 and 1.6.3, so the
# host plugin matches what wireplumber's spa loader expects, and
# SPA_VERSION_HANDLE_FACTORY = 1 so the pipewire ↔ spa-plugin handoff
# is unchanged).
#
# Mechanism:
#   1. runCommand creates an out-path with a single lib/spa-0.2 dir.
#      Every subdir (alsa, audioconvert, dbus, ffmpeg, libcamera, v4l2,
#      …) and top-level entry from pkgs.pipewire/lib/spa-0.2 is
#      symlinked through *except* bluez5.
#   2. bluez5 is symlinked from the 1.6.3 pipewire input instead.
#   3. SPA_PLUGIN_DIR on the pipewire-family user services points at
#      this merged tree. wireplumber is the process that actually
#      loads bluez5; pipewire and pipewire-pulse get it for consistency
#      in case a future version moves bluez5 between processes.
#
# Side-effect: 1.6.3's LDAC codec plugin no longer links libldacBT_dec
# at all (upstream removed the decoder dependency from the codec build,
# moving it elsewhere), so bug 1 disappears for free without any
# libldac-dec patch. Verified with `readelf -d` on the 1.6.3 codec .so.
{
  inputs,
  pkgs,
  ...
}: let
  pinned = import inputs.nixpkgs-pipewire {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  spaDir = pkgs.runCommand "pipewire-spa-bluez5-pin" {} ''
    mkdir -p $out/lib/spa-0.2
    cd $out/lib/spa-0.2
    for entry in ${pkgs.pipewire}/lib/spa-0.2/*; do
      name=$(basename "$entry")
      if [ "$name" != "bluez5" ]; then
        ln -s "$entry" "$name"
      fi
    done
    ln -s ${pinned.pipewire}/lib/spa-0.2/bluez5 bluez5
  '';

  spaPluginDir = "${spaDir}/lib/spa-0.2";
in {
  systemd.user.services.pipewire.environment.SPA_PLUGIN_DIR = spaPluginDir;
  systemd.user.services.pipewire-pulse.environment.SPA_PLUGIN_DIR = spaPluginDir;
  systemd.user.services.wireplumber.environment.SPA_PLUGIN_DIR = spaPluginDir;
}
