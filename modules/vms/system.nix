# Shared NixOS system-level VM configuration
# Imported by both nixos/configuration.nix and handheld/configuration.nix
{
  inputs,
  pkgs,
  ...
}: let
  pinnedVBOX = import inputs.nixpkgs-virtualbox {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in {
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

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["killua"];
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.host.package = pinnedVBOX.virtualbox;

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
}
