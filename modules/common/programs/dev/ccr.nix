# Claude Code Router (CCR) — declarative install + NVIDIA NIM routing.
#
# CCR (https://github.com/musistudio/claude-code-router) is a small Node
# daemon that listens on 127.0.0.1:3456, accepts inbound requests in the
# Anthropic API wire format, and re-translates them to any number of
# OpenAI-compatible providers. Pointing `ANTHROPIC_BASE_URL` at it makes
# `claude`, `ruflo`, `claude-flow`, and any ccmanager-spawned session
# transparently route through whichever model is configured here — no
# per-tool wrapping needed.
#
# ── Pieces ───────────────────────────────────────────────────────────────
# 1. Lazy `npx` shim for `ccr` (same shape as ruflo-cli.nix / claude-flow-cli.nix).
# 2. sops-nix template rendering ~/.claude-code-router/config.json with the
#    NVIDIA API key inlined at activation time (CCR can't read the key from
#    a path, only inline JSON).
# 3. `systemd.user.services.ccr` — always-on daemon (Linux only). On macOS
#    run `ccr start` manually.
# 4. `home.sessionVariables` setting `ANTHROPIC_BASE_URL` + a dummy
#    `ANTHROPIC_API_KEY` so every shell-spawned tool routes via CCR.
{
  pkgs,
  lib,
  config,
  ...
}: let
  # Track upstream's main release. Bump only if a release breaks the CLI
  # surface used here (`ccr start|stop|status|code`).
  ccrVersion = "latest";

  ccrPort = 3456;

  ccr = pkgs.writeShellApplication {
    name = "ccr";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ccr/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/ccr/npm-prefix"
      # npm lstat()s {prefix}/lib and {prefix}/bin on startup — pre-create
      # them so `npx` doesn't ENOENT on first use.
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "@musistudio/claude-code-router@${ccrVersion}" "$@"
    '';
  };

  # CCR config shape — Providers list + a Router that maps Claude Code's
  # logical scenarios (default / background / think / longContext) to a
  # `<provider>,<model>` pair. Add more providers (or a non-NVIDIA fallback)
  # by extending `Providers` and adding the model name to a Router slot.
  ccrConfigAttrs = {
    LOG = false;
    HOST = "127.0.0.1";
    PORT = ccrPort;
    Providers = [
      {
        name = "nvidia-nim";
        api_base_url = "https://integrate.api.nvidia.com/v1/chat/completions";
        api_key = "PLACEHOLDER_NVIDIA_API_KEY";
        models = ["deepseek-ai/deepseek-v4-pro"];
      }
    ];
    Router = {
      default = "nvidia-nim,deepseek-ai/deepseek-v4-pro";
      background = "nvidia-nim,deepseek-ai/deepseek-v4-pro";
      think = "nvidia-nim,deepseek-ai/deepseek-v4-pro";
      longContext = "nvidia-nim,deepseek-ai/deepseek-v4-pro";
    };
  };

  # JSON-encode the attrset, then swap the benign ASCII placeholder for the
  # sops sentinel. Doing it post-toJSON avoids JSON-escaping the sentinel,
  # which contains characters sops-nix recognises verbatim during template
  # expansion.
  ccrConfigJson =
    builtins.replaceStrings
    ["PLACEHOLDER_NVIDIA_API_KEY"]
    [config.sops.placeholder."nvidia_api_key"]
    (builtins.toJSON ccrConfigAttrs);
in {
  home.packages = [ccr];

  # sops template is rendered at HM activation: secrets decrypt → placeholder
  # sentinels are substituted → file is written to `path` with mode 0400
  # owned by the user. CCR reads `~/.claude-code-router/config.json`
  # automatically (no `--config` flag needed).
  sops.templates."claude-code-router-config.json" = {
    content = ccrConfigJson;
    path = "${config.home.homeDirectory}/.claude-code-router/config.json";
  };

  # Always-on daemon so `claude` / `ruflo` / `claude-flow` work without the
  # user remembering to `ccr start` first. Linux only — macOS users run
  # `ccr start` manually until/unless we add a launchd agent.
  systemd.user.services.ccr = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Claude Code Router — Anthropic-API impersonator routing to NVIDIA NIM";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${ccr}/bin/ccr start";
      ExecStop = "${ccr}/bin/ccr stop";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };

  # Single switch that makes claude / ruflo / claude-flow / claude-kit /
  # ccmanager-spawned sessions all auto-route through CCR. CCR ignores the
  # token, but the Anthropic SDK requires *something* non-empty.
  # To bypass for one shell: `unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY`.
  home.sessionVariables = {
    ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString ccrPort}";
    ANTHROPIC_API_KEY = "ccr-local";
  };
}
