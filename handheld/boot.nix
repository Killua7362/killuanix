{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = false;
    configurationLimit = 15;
    default = "saved";
    timeoutStyle = "menu";
    splashImage = null;
    gfxmodeEfi = "1920x1080";
#    theme = "${pkgs.distro-grub-themes}/nixos";
    extraEntries = ''
      menuentry "Windows Boot Manager (on /dev/nvme0n1p1)" --class windows --class os {
        savedefault
        insmod part_gpt
        insmod fat
        search --no-floppy --fs-uuid --set=root 3E7B-8C61
        chainloader /EFI/Microsoft/Boot/bootmgfw-original.efi
      }
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
