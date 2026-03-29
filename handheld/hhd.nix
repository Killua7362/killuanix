# Handheld Daemon (HHD) — controller emulation, TDP, RGB, power button
# Uses the nixpkgs module: nixos/modules/services/hardware/handheld-daemon.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ── Handheld Daemon ──
  services.handheld-daemon = {
    enable = true;
    user = "killua";
    ui.enable = true;

    # TDP adjustor — auto-loads acpi_call kernel module
    adjustor.enable = true;
  };

  # ── Gamescope overlay integration ──
  environment.sessionVariables = {
    HHD_QAM_GAMESCOPE = "1";
  };
}
