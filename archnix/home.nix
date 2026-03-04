{
  pkgs,
  config,
  inputs,
  nixgl,
  libs,
  lib,
  ...
}: {
  imports = [
    ../modules/cross-platform
    ./users/dots-manage.nix
    ../modules/containers/quadlet.nix
    inputs.sops-nix.homeManagerModules.sops
  inputs.spicetify-nix.homeManagerModules.default
  ];

  # home.packages = with pkgs; [
  #     nixgl.nixVulkanIntel
  # ];

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

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default                                    = [ "gtk" "hyprland" ];
        "org.freedesktop.impl.portal.ScreenCast"   = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot"   = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser"  = [ "gtk" ];
      };
      kde = {
        default = [ "kde" "gtk" ];
      };
    };
    xdgOpenUsePortal = true;
  };

  programs.zed-editor.package =(config.lib.nixGL.wrap inputs.zed-editor-flake.packages.${pkgs.stdenv.hostPlatform.system}.zed-editor-bin);
    # systemd.user.services = {
    #   # Ensure pipewire starts correctly
    #   pipewire.Install.WantedBy = [ "default.target" ];
    #   pipewire-pulse.Install.WantedBy = [ "default.target" ];
    #   wireplumber.Install.WantedBy = [ "default.target" ];
    # };

        # home.activation.enableAudioServices = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        #   $DRY_RUN_CMD /usr/bin/systemctl --user mask pulseaudio.service pulseaudio.socket || true
        #   $DRY_RUN_CMD /usr/bin/systemctl --user stop pulseaudio.service pulseaudio.socket || true
        #   $DRY_RUN_CMD /usr/bin/systemctl --user enable --now pipewire.socket       || true
        #   $DRY_RUN_CMD /usr/bin/systemctl --user enable --now pipewire-pulse.socket || true
        #   $DRY_RUN_CMD /usr/bin/systemctl --user enable --now wireplumber.service   || true
        # '';
          wayland.windowManager.hyprland = {
          package =(config.lib.nixGL.wrap inputs.hyprland.packages.${inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.stdenv.hostPlatform.system}.hyprland);
          portalPackage = inputs.hyprland.packages.${ inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        };
  # ── Enable podman user socket (rootless) ──
  systemd.user.services.podman-socket = {
    Unit.Description = "Podman API Socket (rootless)";
    Service = {
      ExecStart = "/usr/bin/podman system service --time=0 unix:///run/user/1000/podman/podman.sock";
      Type = "simple";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };


xdg.configFile."systemd/user/podman-user-wait-network-online.service.d/10-fix-path.conf" = {
  text = ''
    [Service]
    Environment=PATH=/usr/bin:/usr/sbin:/bin:/sbin
  '';
};
  home.stateVersion = "25.11";
}
