# Intel BE200 WiFi suspend fix
# The BE200 fails to resume from D3cold after suspend.
# Source: https://community.intel.com/t5/Wireless/Wifi-be200-not-working-after-suspend/m-p/1694272
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ── Disable D3cold for Intel BE200 WiFi (PCI device 0x272b) ──
  # Prevents WiFi from dying after suspend/resume
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x272b", ATTR{d3cold_allowed}="0"
  '';

  # ── Fallback: reload WiFi modules on suspend/resume ──
  systemd.services.wifi-resume-fix = {
    description = "Reload Intel WiFi modules after resume";
    after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kmod}/bin/modprobe iwlwifi";
    };
  };

  systemd.services.wifi-suspend-unload = {
    description = "Unload Intel WiFi modules before suspend";
    before = ["sleep.target"];
    wantedBy = ["sleep.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.kmod}/bin/modprobe -r iwlmvm iwlwifi || true'";
    };
  };
}
