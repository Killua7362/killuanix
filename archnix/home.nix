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
      inputs.nixgl.overlay
    ];

  targets.genericLinux.nixGL.packages = import nixgl { inherit pkgs; };
  targets.genericLinux.nixGL.defaultWrapper = "mesa";
  targets.genericLinux.nixGL.installScripts = [ "mesa" ];
  targets.genericLinux.nixGL.vulkan.enable = true;

  home.stateVersion = "25.11";
}
