# Shared NixOS system-level VM configuration
# Imported by both chrollo/configuration.nix and killua/configuration.nix
{pkgs, ...}: {
  # VirtualBox removed entirely (2026-08-10): Oracle DB 19c runs under
  # QEMU/KVM now (modules/vms/oracle-19c-vm.nix). Only libvirt/qemu remain.
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
