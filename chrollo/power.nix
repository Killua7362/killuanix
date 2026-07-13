{
  lib,
  pkgs,
  ...
}: {
  # Battery/power tuning for chrollo (Raptor Lake-P laptop, 44Wh).
  #
  # Root cause of poor runtime was the CPU sitting on the "performance"
  # power-profiles-daemon profile (EPP=performance on every core) plus PCI
  # devices with runtime PM disabled. This module keeps ppd as the profile
  # manager, adds powertop auto-tune for device-level runtime PM, and biases
  # the default profile toward balanced so a stray "performance" toggle does
  # not silently persist across reboots (ppd remembers the last profile in
  # /var/lib/power-profiles-daemon/state.ini).

  # Profile manager. ppd owns CPU EPP + platform_profile; it flips EPP to
  # balance_power on the balanced/power-saver profiles.
  services.power-profiles-daemon.enable = true;

  # powertop --auto-tune at boot: enables runtime PM on the PCI devices that
  # were stuck power/control=on, plus USB/SATA autosuspend. Complements ppd
  # (device-level PM, not CPU governor) rather than conflicting with it.
  powerManagement.powertop.enable = true;

  # Lid close locks the session instead of suspending. Default
  # HandleLidSwitch=suspend cut the screen and dropped wifi (suspend tears down
  # the radio); "lock" keeps the machine running with the network up and just
  # locks. logind emits the login1 session Lock signal, which DMS handles via
  # loginctlLockIntegration=true (dms/lock-power.nix) → DMS lock screen. hypridle
  # also listens for that signal, so its lock_cmd is pointed at the same DMS
  # locker (hyprland/hypridle.nix) to avoid two ext-session-lock clients racing.
  # All three cases (bare/on-AC/docked) lock.
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
    # Power button (short press) suspends instead of powering off. DMS locks
    # first via lockBeforeSuspend (dms/lock-power.nix) so the machine sleeps
    # locked. Long press stays "ignore" so the Hyprland bind
    # (chrollo/home-manager/device-keybinds.lua) can own it → DMS power menu.
    # Plain lock (no suspend) is the Super+L keybind.
    HandlePowerKey = "suspend";
  };

  # Set the correct initial profile at boot to match the AC state: performance
  # on mains, balanced on battery. DMS's BatteryService only re-asserts on the
  # plug/unplug *event* (onIsPluggedInChanged), not at startup, so without this
  # the boot profile would be whatever ppd last remembered. Same rule as the
  # DMS auto-switch (acProfileName="2" / batteryProfileName="1" in
  # dms/lock-power.nix), so the two never disagree — this just seeds t=0.
  systemd.services.power-profile-boot = {
    description = "Seed power profile from AC state on boot";
    after = ["power-profiles-daemon.service"];
    wants = ["power-profiles-daemon.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "power-profile-boot" ''
        online=0
        for t in /sys/class/power_supply/*/type; do
          [ "$(cat "$t" 2>/dev/null)" = "Mains" ] || continue
          [ "$(cat "$(dirname "$t")/online" 2>/dev/null)" = "1" ] && online=1
        done
        if [ "$online" = "1" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
        else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
        fi
      '';
    };
  };
}
