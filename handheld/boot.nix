# GRUB2 bootloader with theming for MSI Claw handheld
# Replaces systemd-boot; detects Windows via os-prober
{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
    configurationLimit = 15;
    default = "saved";
    timeoutStyle = "menu";
    splashImage = null;
    gfxmodeEfi = "1920x1080";
    theme = "${pkgs.distro-grub-themes}/nixos";
    extraEntries = ''
      menuentry "Reboot" --class restart {
        reboot
      }
      menuentry "Shutdown" --class shutdown {
        halt
      }
    '';
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
