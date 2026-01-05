{
  pkgs,
  config,
  inputs,
  nixgl,
  libs,
  ...
}: {
  imports = [
    ../modules/cross-platform
    ./users/dots-manage.nix
  ];

    nix.package = pkgs.nix;

    # Arch-specific overlays
    nixpkgs.overlays = [
      inputs.nur.overlays.default
      # inputs.nixgl.overlay
      inputs.neovim-nightly-overlay.overlays.default
    ];

  # targets.genericLinux.enable = true;

  # Linux-specific state version
  home.stateVersion = "25.11";
}
