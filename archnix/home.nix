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

    nixpkgs.overlays = [
      inputs.nur.overlays.default
      inputs.neovim-nightly-overlay.overlays.default
      inputs.yazi.overlays.default
          inputs.nix-yazi-flavors.overlays.default
    ];

  # targets.genericLinux.enable = true;

  # Linux-specific state version
  home.stateVersion = "25.11";
}
