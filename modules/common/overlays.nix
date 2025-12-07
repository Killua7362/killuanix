{
  # Common overlays that are useful across all systems
  commonOverlays = [
    # Package overlays that work on all systems
    "prefmanager"
  ];

  # Linux-specific overlays
  linuxOverlays = [
    # Add Linux-specific overlays here
  ];

  # Darwin (macOS)-specific overlays
  darwinOverlays = [
    # Darwin-specific overlays
    "apple-silicon"
  ];

  # x86_64-specific overlays
  x86_64Overlays = [
    # Add x86_64-specific overlays here
  ];

  # aarch64-specific overlays
  aarch64Overlays = [
    # Add aarch64-specific overlays here
  ];

  # Channel overlays (these provide access to different nixpkgs channels)
  channelOverlays = [
    "unstable-packages"
    "pkgs-master"
    "pkgs-stable"
    "pkgs-unstable"
  ];
}
