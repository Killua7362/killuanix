# claudio — hook-based audio plugin for Claude Code.
#
# https://github.com/ctoth/claudio — Go binary that reads a Claude Code hook
# JSON payload on stdin, parses the tool/command, and plays a contextual sound
# (success/error/loading/interactive). Falls back through soundpack rules
# (e.g. `success/git-commit-success.wav` → `success/git-success.wav` →
# `success/bash-success.wav` → `success/success.wav` → `default.wav`).
# With no soundpack configured it uses platform built-ins
# (Glass/Hero/Purr on macOS, Windows Media via /mnt/c/... under WSL, basic
# fallback on plain Linux).
#
# Wiring: install the binary, then register it under PreToolUse / PostToolUse /
# UserPromptSubmit hook events with a `"*"` matcher. claudio decides what to
# play from the stdin payload, so a single command per event is enough.
#
# To silence without rebuilding: `export CLAUDIO_ENABLED=false` in the shell
# launching claude. To bump: change `claudioVersion`/`claudioRev` + flip
# `vendorHash` to `lib.fakeHash`, run `scripts/nix_switch`, paste the real
# hash from the failure back in.
{
  pkgs,
  lib,
  ...
}: let
  claudioVersion = "1.13.1";
  claudioRev = "a9bc1f521f350bf7292b204528ac35c61fb7f122";

  claudio = pkgs.buildGoModule {
    pname = "claudio";
    version = claudioVersion;

    src = pkgs.fetchFromGitHub {
      owner = "ctoth";
      repo = "claudio";
      rev = claudioRev;
      hash = "sha256-Ea0iAvUKPE8UHfhwOelj2lhaHnAr80jZtQQvwT6Ki3c=";
    };

    vendorHash = "sha256-ws7q63PTJ+QLn9lkgDL/kXAIj8vKvheTNNQedButVQQ=";

    # malgo's miniaudio shim links -ldl -lpthread -lm on Linux and pulls
    # CoreAudio/AudioToolbox frameworks via cgo on Darwin. ALSA/PulseAudio
    # backends are dlopen'd at runtime, so no extra buildInputs are needed.
    subPackages = ["cmd/claudio"];

    # Upstream wires `claudio install` to mutate ~/.claude/settings.json on
    # first run — we wire the hooks declaratively below, so the install
    # subcommand is unused (but still present in the binary).

    meta = with lib; {
      description = "Hook-based audio plugin for Claude Code";
      homepage = "https://github.com/ctoth/claudio";
      license = licenses.mit;
      mainProgram = "claudio";
      platforms = platforms.unix;
    };
  };

  # Each Claude Code hook entry is `{ matcher, hooks: [{type, command, timeout}] }`.
  # `"*"` matches every tool name. claudio reads the full payload on stdin and
  # short-circuits when CLAUDIO_ENABLED=false, so a no-op invocation is cheap.
  claudioHook = matcher: [
    {
      inherit matcher;
      hooks = [
        {
          type = "command";
          command = "${lib.getExe claudio}";
          timeout = 5;
        }
      ];
    }
  ];
  claudioHookNoMatcher = [
    {
      hooks = [
        {
          type = "command";
          command = "${lib.getExe claudio}";
          timeout = 5;
        }
      ];
    }
  ];
in {
  home.packages = [claudio];

  # Contribute through the shared `local.extraHooks` side-channel (declared in
  # ./claude.nix) so claude-hooks and any future hook source can co-register
  # entries for the same events without clobbering us.
  local.extraHooks = {
    PreToolUse = claudioHook "*";
    PostToolUse = claudioHook "*";
    UserPromptSubmit = claudioHookNoMatcher;
  };
}
