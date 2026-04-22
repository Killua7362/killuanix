# Audio Module

Home Manager module for audio tooling, PipeWire/WirePlumber configuration, Bluetooth audio, and Spotify (via spicetify-nix).

## Files

| File | Description |
|---|---|
| `default.nix` | Entry point; imports `shared.nix` and `spotify.nix` |
| `shared.nix` | Audio packages, user services, and PipeWire/WirePlumber XDG config drop-ins |
| `spotify.nix` | Spotify client configured through `spicetify-nix` with extensions, custom apps, snippets, and the Dribbblish theme (lunar color scheme) |

## Packages (shared.nix)

**Audio GUI:** pavucontrol, pwvucontrol, crosspipe, qpwgraph

**Audio CLI/TUI:** pamixer, playerctl, pulsemixer

**Bluetooth GUI:** blueman

## User Services (shared.nix)

- `blueman-applet` -- Bluetooth system tray applet
- `mpris-proxy` -- Exposes MPRIS controls over Bluetooth (AVRCP)
- `playerctld` -- Daemon for `playerctl` to track the active media player

## PipeWire / WirePlumber Configuration (shared.nix)

All config is written as XDG config drop-ins under `~/.config/pipewire/` and `~/.config/wireplumber/`, so it works on both NixOS and Arch.

- **PipeWire core** -- 48 kHz default rate (allows 44.1/96 kHz), quantum 1024 (min 512, max 2048), real-time scheduling (nice -11, rt prio 88).
- **PulseAudio bridge** -- Per-application latency rules: browsers/Electron get 1024/48000; gaming processes (Steam, Gamescope, Wine/Proton) get 512/48000.
- **JACK bridge** -- 256/48000 latency, short names, monitor merging enabled.
- **Bluetooth (WirePlumber)** -- Enables SBC-XQ, mSBC, hardware volume, native HFP/HSP backend, auto-switch to HSP/HFP on mic request, preferred codec order (LDAC > aptX HD > aptX > aptX LL > AAC > SBC-XQ > SBC > FastStream > LC3plus > LC3). A separate rule auto-connects `a2dp_sink` and enables hardware volume on `hfp_ag`/`hsp_ag`/`a2dp_sink` for all BlueZ cards.
- **ALSA tuning** -- Period size 1024, headroom 1024, resample quality 10, suspend disabled. HDMI and loopback outputs are hidden.

## Spotify (spotify.nix)

Uses the `spicetify-nix` flake input. Enabled extensions: adblock, hidePodcasts, shuffle+. Custom apps: newReleases, ncsVisualizer. Snippets: rotatingCoverart, pointer. Theme: Dribbblish (lunar).

## Integration

`default.nix` is imported by `modules/common/programs.nix`, which aggregates all per-program Home Manager modules for cross-platform use.
