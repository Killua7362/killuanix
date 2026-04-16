# LiteLLM + MCP Runtime (NixOS, rootful Quadlet).
#
# Builds a container image that bundles LiteLLM with every MCP server declared
# in modules/common/mcp-servers.nix, pre-warmed via npx/uvx at image build time
# (no Nix hashes for individual MCP packages — podman handles the npm/PyPI fetch).
#
# API keys are read from sops-nix system-level secrets (see modules/common/sops-system.nix).
# A oneshot service assembles /run/litellm/env from the decrypted files.
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  registry = inputs.self.commonModules.mcpServers;

  # ── Derived MCP install lines ──
  npxPackages = lib.unique (lib.mapAttrsToList (_: s: s.package) (lib.filterAttrs (_: s: s.runtime == "npx") registry));
  uvxPackages = lib.unique (lib.mapAttrsToList (_: s: s.package) (lib.filterAttrs (_: s: s.runtime == "uvx") registry));

  npxInstallLines = lib.concatMapStringsSep "\n" (p: "RUN npx -y ${p} --help </dev/null &>/dev/null || true") npxPackages;
  uvxInstallLines = lib.concatMapStringsSep "\n" (p: "RUN uvx ${p} --help </dev/null &>/dev/null || true") uvxPackages;

  # ── LiteLLM proxy config ──
  litellmConfig = pkgs.writeText "litellm-config.yaml" (builtins.toJSON {
    model_list = [
      {
        model_name = "gemini-pro";
        litellm_params = {
          model = "gemini/gemini-2.5-pro-preview-06-05";
          api_key = "os.environ/GOOGLE_API_KEY";
        };
      }
      {
        model_name = "gemini-flash";
        litellm_params = {
          model = "gemini/gemini-2.5-flash-preview-05-20";
          api_key = "os.environ/GOOGLE_API_KEY";
        };
      }
      {
        model_name = "mistral-large";
        litellm_params = {
          model = "mistral/mistral-large-latest";
          api_key = "os.environ/MISTRAL_API_KEY";
        };
      }
      {
        model_name = "codestral";
        litellm_params = {
          model = "mistral/codestral-latest";
          api_key = "os.environ/MISTRAL_CODESTRAL_API_KEY";
        };
      }
      {
        model_name = "nvidia-nemotron";
        litellm_params = {
          model = "nvidia_nim/nvidia/llama-3.1-nemotron-ultra-253b-v1";
          api_key = "os.environ/NVIDIA_API_KEY";
        };
      }
    ];
    general_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
    };
  });

  # ── Combined LiteLLM + MCP image ──
  # Built from python:3.12-slim so we control the base distro. Upstream
  # ghcr.io/berriai/litellm:main-latest recently switched to a minimal base
  # without apt-get, which broke the previous layered approach.
  dockerfile = pkgs.writeText "Dockerfile.litellm-mcp" ''
    FROM python:3.12-slim

    # System deps + Node.js 22 (for npx MCP servers)
    RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git \
      && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
      && apt-get install -y --no-install-recommends nodejs \
      && rm -rf /var/lib/apt/lists/*

    # uv (provides uvx for PyPI MCP servers)
    RUN curl -LsSf https://astral.sh/uv/install.sh | sh
    ENV PATH="/root/.local/bin:$PATH"

    # LiteLLM proxy
    RUN pip install --no-cache-dir "litellm[proxy]"

    # Pre-warm MCP servers (auto-generated from modules/common/mcp-servers.nix)
    ${npxInstallLines}
    ${uvxInstallLines}

    EXPOSE 4000
    ENTRYPOINT ["litellm"]
  '';

  buildContext = let
    dockerignore = pkgs.writeText ".dockerignore.litellm-mcp" "*";
  in
    pkgs.runCommand "litellm-mcp-context" {} ''
      mkdir -p $out
      cp ${dockerfile} $out/Dockerfile
      cp ${dockerignore} $out/.dockerignore
    '';

  # Map sops secret names to decrypted runtime paths (NixOS sops-nix default).
  sopsPath = name: config.sops.secrets.${name}.path;
in {
  virtualisation.quadlet = {
    builds.litellm = {
      buildConfig = {
        tag = "localhost/litellm-mcp:latest";
        file = "${buildContext}/Dockerfile";
        workdir = "${buildContext}";
        pull = "missing";
      };
      serviceConfig.TimeoutStartSec = 900;
      unitConfig.Description = "Build LiteLLM+MCP Runtime OCI image";
    };

    containers.litellm = {
      autoStart = true;

      containerConfig = {
        image = "localhost/litellm-mcp:latest";
        publishPorts = ["4000:4000"];
        volumes = [
          "${litellmConfig}:/app/config.yaml:ro,z"
          "/home/killua:/home/killua:z"
          "mcp-npm-cache:/root/.npm"
          "mcp-uv-cache:/root/.local/share/uv"
        ];
        environments = {
          LITELLM_MASTER_KEY = "sk-litellm-local";
        };
        environmentFiles = ["/run/litellm/env"];
        exec = "--config /app/config.yaml --port 4000";
        labels = ["io.containers.autoupdate=registry"];
      };

      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = 600;
      };

      unitConfig = {
        Description = "LiteLLM + MCP Runtime";
        After = [
          "network-online.target"
          "podman.socket"
          "litellm-build.service"
          "litellm-env.service"
        ];
        Requires = [
          "podman.socket"
          "litellm-build.service"
          "litellm-env.service"
        ];
      };
    };

    volumes = {
      mcp-npm-cache.volumeConfig = {};
      mcp-uv-cache.volumeConfig = {};
    };
  };

  # Assemble /run/litellm/env from sops-decrypted secrets before the container starts.
  # sops-nix materialises secrets to /run/secrets/ during NixOS activation (not via
  # a systemd unit), so by the time any [Install] WantedBy=multi-user.target service
  # starts the files already exist. No explicit dependency on a sops unit is needed.
  systemd.services.litellm-env = {
    description = "Assemble LiteLLM env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "litellm";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      read_secret() {
        local path="$1"
        [ -f "$path" ] && cat "$path" || echo ""
      }

      umask 077
      {
        printf 'NVIDIA_API_KEY=%s\n' "$(read_secret ${sopsPath "nvidia_api_key"})"
        printf 'GOOGLE_API_KEY=%s\n'  "$(read_secret ${sopsPath "google_studio_key"})"
        printf 'MISTRAL_API_KEY=%s\n' "$(read_secret ${sopsPath "mistral_api_key"})"
        printf 'MISTRAL_CODESTRAL_API_KEY=%s\n' "$(read_secret ${sopsPath "mistral_codestral_api_key"})"
      } > /run/litellm/env
    '';
  };
}
