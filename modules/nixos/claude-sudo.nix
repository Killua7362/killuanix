# Passwordless `ss` for Claude Code (Option B).
#
# `ss` (iproute2 socket stats) is read-only: it can't spawn a shell, read
# arbitrary files, or mutate the system, so making it passwordless grants NO
# root-escape path — unlike `nixos-rebuild`, which would let a hijacked Claude
# read the age key and disable any control. This is what keeps the secret-dir
# masking (bwrap mount namespace in claude.nix) adversary-resistant: no
# unattended root exists to tear the namespace down.
#
# Every OTHER privileged command Claude needs goes through `pkexec` → the
# hyprpolkitagent GUI dialog (already autostarted in hyprland/lua/execs.lua):
# the password flows agent→polkitd only (never on disk, never into Claude),
# and the command's stdout returns to Claude normally.
#
# Imported by chrollo/configuration.nix and killua/configuration.nix.
{...}: {
  security.sudo.extraRules = [
    {
      users = ["killua"];
      runAs = "root";
      commands = [
        {
          # Binary-scoped: `sudo ss <anything>` is passwordless. Stable path
          # (symlink into the active system), so it survives rebuilds.
          command = "/run/current-system/sw/bin/ss";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
