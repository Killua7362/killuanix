# Handheld Daemon (HHD) — DISABLED in favor of InputPlumber (from Jovian)
# InputPlumber handles controller emulation; steamos-manager handles TDP/power.
# HHD and InputPlumber cannot coexist (both grab the same input devices → EBUSY loop → system freeze).
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.handheld-daemon = {
    enable = false;
  };
}
