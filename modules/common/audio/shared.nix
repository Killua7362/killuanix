{ config, pkgs, lib, ... }:

{
  # ╔══════════════════════════════════════════════════════════════════╗
  # ║  User Packages (managed by Home Manager on BOTH systems)         ║
  # ╚══════════════════════════════════════════════════════════════════╝
  home.packages = with pkgs; [
    # Audio GUI tools
    pavucontrol           # PulseAudio-compatible GTK mixer
    pwvucontrol           # PipeWire-native volume control
    helvum                # PipeWire patchbay (visual node graph)
    qpwgraph              # Alternative Qt-based patchbay

    # Audio CLI tools
    pamixer               # CLI volume control
    playerctl             # MPRIS media player control
    pulsemixer            # TUI mixer

    # Bluetooth GUI
    blueman               # Bluetooth manager + applet
  ];

  # ╔══════════════════════════════════════════════════════════════════╗
  # ║  User Services (Home Manager managed, both systems)              ║
  # ╚══════════════════════════════════════════════════════════════════╝
  services.blueman-applet.enable = true;
  services.mpris-proxy.enable = true;
  services.playerctld.enable = true;

  # ╔══════════════════════════════════════════════════════════════════╗
  # ║  PipeWire Config (drop-ins in ~/.config/pipewire/)               ║
  # ║  Works on both Arch and NixOS — user-level overrides             ║
  # ╚══════════════════════════════════════════════════════════════════╝
  xdg.configFile = {

    # ── PipeWire Core ─────────────────────────────────────────────
    "pipewire/pipewire.conf.d/99-custom.conf".text = ''
      context.properties = {
          default.clock.rate            = 48000
          default.clock.allowed-rates   = [ 44100 48000 96000 ]
          default.clock.quantum         = 1024
          default.clock.min-quantum     = 512 # switch to 32 for lower latency
          default.clock.max-quantum     = 2048
          default.clock.force-quantum   = 0
      }

      context.modules = [
          {   name = libpipewire-module-rt
              args = {
                  nice.level   = -11
                  rt.prio      = 88
                  rt.time.soft = -1
                  rt.time.hard = -1
              }
              flags = [ ifexists nofail ]
          }
      ]
    '';

    # ── PulseAudio Bridge ─────────────────────────────────────────
    "pipewire/pipewire-pulse.conf.d/99-custom.conf".text = ''
      pulse.properties = {
          server.address = [ "unix:native" ]
      }

      pulse.rules = [
          {
              # Browsers & Electron apps (Discord, Slack, etc.)
              matches = [
                  { application.process.binary = "~firefox|chromium|chrome|electron.*|Discord|slack" }
              ]
              actions = {
                  update-props = {
                      pulse.min.req     = 1024/48000
                      pulse.min.quantum = 1024/48000
                  }
              }
          }
          {
              # Gaming — lower latency
              matches = [
                  { application.process.binary = "~steam|gamescope|wine.*|proton.*" }
              ]
              actions = {
                  update-props = {
                      pulse.min.req     = 512/48000
                      pulse.min.quantum = 512/48000
                  }
              }
          }
      ]
    '';

    # ── JACK Bridge ───────────────────────────────────────────────
    "pipewire/pipewire-jack.conf.d/99-custom.conf".text = ''
      jack.properties = {
          rt.prio             = 88
          node.latency        = 256/48000
          jack.short-name     = true
          jack.merge-monitor  = true
          jack.show-monitor   = true
          jack.filter-name    = false
          jack.locked-process = true
      }
    '';

    # ── WirePlumber: Bluetooth ────────────────────────────────────
    "wireplumber/wireplumber.conf.d/50-bluez-config.conf".text = ''
      monitor.bluez.properties = {
          bluez5.enable-sbc-xq    = true
          bluez5.enable-msbc      = true
          bluez5.enable-hw-volume = true
          bluez5.hfphsp-backend   = "native"

          bluez5.roles = [
              a2dp_sink a2dp_source
              bap_sink bap_source
              hsp_hs hsp_ag
              hfp_hf hfp_ag
          ]

          bluez5.codecs = [
              ldac
              aptx_hd aptx aptx_ll aptx_ll_duplex
              aac
              sbc_xq sbc
              faststream faststream_duplex
              lc3plus_h3 lc3
          ]
      }
    '';

    # ── WirePlumber: Bluetooth auto-switch ────────────────────────
    "wireplumber/wireplumber.conf.d/50-bluez-autoswitch.conf".text = ''
      wireplumber.settings = {
          # When an app requests a microphone (e.g. Google Meet, Discord),
          # automatically switch BT headset from A2DP (music) to
          # HSP/HFP (voice) profile
          bluetooth.autoswitch-to-headset-profile = true
      }

      wireplumber.profiles = {
          main = {
              monitor.bluez.seat-monitoring = required
          }
      }
    '';

"wireplumber/wireplumber.conf.d/52-bluetooth-nrec.conf".text = ''
  monitor.bluez.rules = [
    {
      matches = [
        {
          device.name = "~bluez_card.*"
        }
      ]
      actions = {
        update-props = {
          bluez5.auto-connect  = [ a2dp_sink ]
          bluez5.hw-volume     = [ hfp_ag hsp_ag a2dp_sink ]
        }
      }
    }
  ]
'';

    # ── WirePlumber: ALSA tuning ──────────────────────────────────
    "wireplumber/wireplumber.conf.d/50-alsa-config.conf".text = ''
      monitor.alsa.rules = [
          {
              matches = [ { node.name = "~alsa_output.*" } ]
              actions = {
                  update-props = {
                      api.alsa.period-size            = 1024
                      api.alsa.headroom               = 1024
                      resample.quality                = 10
                      session.suspend-timeout-seconds  = 0
                      channelmix.normalize            = false
                      channelmix.mix-lfe              = false
                  }
              }
          }
          {
              matches = [ { node.name = "~alsa_input.*" } ]
              actions = {
                  update-props = {
                      api.alsa.period-size            = 1024
                      api.alsa.headroom               = 1024
                      resample.quality                = 10
                      session.suspend-timeout-seconds  = 0
                  }
              }
          }
          # ── Hide HDMI outputs ──
          {
              matches = [
                  { node.name        = "~alsa_output.*hdmi.*" }
                  { node.description = "~.*HDMI.*" }
              ]
              actions = {
                  update-props = {
                      node.disabled = true
                  }
              }
          }
          # ── Hide Loopback outputs ──
          {
              matches = [
                  { node.name        = "~alsa_output.*[Ll]oopback.*" }
                  { node.description = "~.*[Ll]oopback.*" }
              ]
              actions = {
                  update-props = {
                      node.disabled = true
                  }
              }
          }
      ]
    '';

  };
}
