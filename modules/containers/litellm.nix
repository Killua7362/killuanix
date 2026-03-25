{
  pkgs,
  config,
  lib,
  ...
}: let
  # ── Declarative MCP server definitions ──
  # Add entries here to install into the container AND register with Claude.
  #
  # Fields:
  #   runtime  — "npx" or "uvx"
  #   package  — npm package name or PyPI package name
  #   args     — extra CLI args appended after the package (optional)
  #   env      — environment variables passed to Claude (optional)
  mcpServers = {
    filesystem = {
      runtime = "npx";
      package = "@modelcontextprotocol/server-filesystem";
      args = [config.home.homeDirectory];
    };

    fetch = {
      runtime = "uvx";
      package = "mcp-server-fetch";
    };

    memory = {
      runtime = "npx";
      package = "@modelcontextprotocol/server-memory";
      env.MEMORY_FILE_PATH = "${config.xdg.dataHome}/claude/memory.json";
    };

    sequential-thinking = {
      runtime = "npx";
      package = "@modelcontextprotocol/server-sequential-thinking";
    };
  };

  # ── Derived MCP values ──
  npxPackages = lib.unique (lib.mapAttrsToList (_: s: s.package) (lib.filterAttrs (_: s: s.runtime == "npx") mcpServers));
  uvxPackages = lib.unique (lib.mapAttrsToList (_: s: s.package) (lib.filterAttrs (_: s: s.runtime == "uvx") mcpServers));

  npxInstallLines = lib.concatMapStringsSep "\n" (p: "RUN npx -y ${p} --help </dev/null &>/dev/null || true") npxPackages;
  uvxInstallLines = lib.concatMapStringsSep "\n" (p: "RUN uvx ${p} --help </dev/null &>/dev/null || true") uvxPackages;

  claudeMcpServers = lib.mapAttrs (_: s: let
    runtimeArgs =
      if s.runtime == "npx"
      then ["npx" "-y" s.package]
      else ["uvx" s.package];
    extraArgs = s.args or [];
  in
    {
      command = "podman";
      args = ["exec" "-i" "litellm"] ++ runtimeArgs ++ extraArgs;
    }
    // lib.optionalAttrs (s ? env) {env = s.env;})
  mcpServers;

  # ── LiteLLM config ──
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

  # ── Combined LiteLLM + MCP container image ──
  dockerfile = pkgs.writeText "Dockerfile.litellm-mcp" ''
    FROM ghcr.io/berriai/litellm:main-latest

    USER root

    RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git \
      && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
      && apt-get install -y --no-install-recommends nodejs \
      && rm -rf /var/lib/apt/lists/*

    # Install uv (provides uvx)
    RUN curl -LsSf https://astral.sh/uv/install.sh | sh
    ENV PATH="/root/.local/bin:$PATH"

    # Pre-install MCP servers (generated from mcpServers attrset)
    ${npxInstallLines}
    ${uvxInstallLines}
  '';

  buildContext = let
    dockerignore = pkgs.writeText ".dockerignore.litellm-mcp" "*";
  in
    pkgs.runCommand "litellm-mcp-context" {} ''
      mkdir -p $out
      cp ${dockerfile} $out/Dockerfile
      cp ${dockerignore} $out/.dockerignore
    '';
in {
  programs.claude-code.mcpServers = claudeMcpServers;

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
        publishPorts = [
          "4000:4000"
        ];
        volumes = [
          "${litellmConfig}:/app/config.yaml:ro,z"
          "${config.home.homeDirectory}:${config.home.homeDirectory}:z"
          "mcp-npm-cache:/root/.npm"
          "mcp-uv-cache:/root/.local/share/uv"
        ];
        environments = {
          LITELLM_MASTER_KEY = "sk-litellm-local";
        };
        environmentFiles = [
          "${config.xdg.configHome}/litellm/env"
        ];
        exec = "--config /app/config.yaml --port 4000";
        labels = [
          "io.containers.autoupdate=registry"
        ];
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
        ];
        Requires = [
          "podman.socket"
          "litellm-build.service"
        ];
      };
    };

    volumes = {
      mcp-npm-cache.volumeConfig = {};
      mcp-uv-cache.volumeConfig = {};
    };
  };

  # LiteLLM env file with API keys from sops
  home.activation.litellmEnv = lib.hm.dag.entryAfter ["writeBoundary" "sopsNix"] (let
    envDir = "${config.xdg.configHome}/litellm";
  in ''
        mkdir -p "${envDir}"

        NVIDIA_KEY=""
        GOOGLE_KEY=""
        MISTRAL_KEY=""
        MISTRAL_CODESTRAL_KEY=""

        [ -f "${config.sops.secrets."nvidia_api_key".path}" ] && NVIDIA_KEY=$(cat "${config.sops.secrets."nvidia_api_key".path}")
        [ -f "${config.sops.secrets."google_studio_key".path}" ] && GOOGLE_KEY=$(cat "${config.sops.secrets."google_studio_key".path}")
        [ -f "${config.sops.secrets."mistral_api_key".path}" ] && MISTRAL_KEY=$(cat "${config.sops.secrets."mistral_api_key".path}")
        [ -f "${config.sops.secrets."mistral_codestral_api_key".path}" ] && MISTRAL_CODESTRAL_KEY=$(cat "${config.sops.secrets."mistral_codestral_api_key".path}")

        printf '%s\n' \
          "NVIDIA_API_KEY=$NVIDIA_KEY" \
          "GOOGLE_API_KEY=$GOOGLE_KEY" \
          "MISTRAL_API_KEY=$MISTRAL_KEY" \
          "MISTRAL_CODESTRAL_API_KEY=$MISTRAL_CODESTRAL_KEY" \
          > "${envDir}/env"

        chmod 600 "${envDir}/env"
  '');
}
