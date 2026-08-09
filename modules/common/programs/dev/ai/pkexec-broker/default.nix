# pkexec-broker — lets Claude Code run `pkexec <cmd>` from inside its bwrap
# secret-dir sandbox (Option B, generalized).
#
# Problem: overlayClaude (claude.nix) runs claude under bwrap with the two
# secret dirs masked. `pkexec` doesn't change the mount namespace, so a pkexec
# launched from inside the sandbox would still see the masked (empty) dirs —
# breaking nixos-rebuild's sops decryption and any other privileged command
# that needs them.
#
# Solution: a tiny broker service in the *graphical session* (outside bwrap).
# A `pkexec` client shim on Claude's PATH (injected ONLY inside the sandbox via
# overlayClaude's --setenv PATH, using the local.claudeExtraPath side-channel
# declared in claude.nix) forwards each invocation to the broker over a unix
# socket. The broker runs the real pkexec there → runs in the host namespace
# (secret dirs visible) → hyprpolkitagent shows the GUI password dialog →
# stdout/stderr/exit stream back. Transparent: Claude just runs `pkexec <cmd>`.
#
# The user's own terminal is unaffected — the shim is NOT in home.packages, so
# `pkexec` there is still the real /run/wrappers/bin/pkexec.
#
# Linux-only (bwrap / systemd --user / polkit). Imported by ./default.nix.
{
  pkgs,
  lib,
  config,
  ...
}: let
  py = pkgs.python3;

  # The real nix_switch (DotFiles submodule) the broker runs AS THE USER.
  nixSwitch = "${config.home.homeDirectory}/killuanix/DotFiles/scripts/personal/nix_switch";

  broker = pkgs.runCommand "pkexec-broker" {nativeBuildInputs = [py];} ''
    mkdir -p $out/bin
    substitute ${./broker.py} $out/bin/pkexec-broker \
      --replace-fail '@pkexec@' '/run/wrappers/bin/pkexec' \
      --replace-fail '@nixswitch@' '${nixSwitch}'
    chmod +x $out/bin/pkexec-broker
    patchShebangs $out/bin/pkexec-broker
  '';

  # One script, two shims. Installed as `pkexec` and `nix_switch` so both shadow
  # the real ones on Claude's sandbox PATH (behaviour keyed on invoked name).
  client = pkgs.runCommand "claude-pkexec-client" {nativeBuildInputs = [py];} ''
    mkdir -p $out/bin
    install -m0755 ${./client.py} $out/bin/pkexec
    ln -s pkexec $out/bin/nix_switch
    patchShebangs $out/bin/pkexec
  '';
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    systemd.user.services.pkexec-broker = {
      Unit = {
        Description = "pkexec broker for Claude Code (runs pkexec outside Claude's bwrap namespace)";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${broker}/bin/pkexec-broker";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    # Prepend the `pkexec` shim to PATH INSIDE Claude's bwrap sandbox only
    # (consumed by overlayClaude in claude.nix). Deliberately NOT home.packages.
    local.claudeExtraPath = ["${client}/bin"];
  };
}
