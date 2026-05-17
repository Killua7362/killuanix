# Shared NixOS system-level VM configuration
# Imported by both chrollo/configuration.nix and killua/configuration.nix
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  pinnedVBOX = import inputs.nixpkgs-virtualbox {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  cfg = config.vms.virtualbox;
in {
  options.vms.virtualbox.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to enable the VirtualBox host (kernel modules + extpack).
      Disabled on killua (handheld) because the Oracle DB 19c image runs
      under QEMU/KVM instead — dropping VBox eliminates the per-rebuild
      virtualbox-modules-<vbox>-<kernel> source build (~3-5 min, never
      on any public cache).
    '';
  };

  config = {
    boot.extraModprobeConfig = "options kvm-intel nested=1";

    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        vhostUserPackages = [pkgs.virtiofsd];
      };
    };

    programs.virt-manager.enable = true;

    virtualisation.virtualbox.host = lib.mkIf cfg.enable {
      enable = true;
      enableExtensionPack = true;
      package = pinnedVBOX.virtualbox;
    };
    users.extraGroups.vboxusers.members = lib.mkIf cfg.enable ["killua"];

    # Autostart the default NAT network for VMs
    systemd.services.libvirtd-default-network = {
      description = "Autostart libvirt default network";
      after = ["libvirtd.service"];
      requires = ["libvirtd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true
        ${pkgs.libvirt}/bin/virsh net-autostart default 2>/dev/null || true
      '';
    };

    environment.systemPackages = with pkgs; [
      virt-viewer
      virt-top
    ];
  };
}
