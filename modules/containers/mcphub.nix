{ pkgs, config, lib, ... }:
let
  mcp-dockerfile = pkgs.writeText "Dockerfile" ''
    # syntax=docker/dockerfile:1

    # Build stage
    FROM node:18-alpine AS build
    WORKDIR /app
    RUN apk add --no-cache python3 make g++
    COPY package*.json ./
    RUN npm ci
    COPY . ./
    RUN npm run build

    # Runtime stage
    FROM node:18-alpine
    WORKDIR /app
    COPY --from=build /app/dist ./dist
    COPY --from=build /app/package*.json ./
    RUN npm ci --omit=dev
    RUN apk add --no-cache docker-cli

    EXPOSE 31415

    ENTRYPOINT ["node", "dist/cli.js"]
    CMD ["--port", "31415", "--config", "/config/mcp-servers.json"]
  '';

  dockerignore = pkgs.writeText ".dockerignore" ''
    node_modules
    npm-debug.log
    tests
    .vscode
    .git
    .gitignore
    *.md
    *.log
    examples
    *.local
    *.env
    *.DS_Store
  '';

  mcp-server-src = pkgs.fetchFromGitHub {
    owner = "ravitemer";
    repo  = "mcp-hub";
    rev   = "9c7670a4c341ed3cf738a6242c0fde1cea40bccf";
    hash  = "sha256-KakvXZf0vjdqzyT+LsAKHEr4GLICGXPmxl1hZ3tI7Yg=";
  };

  buildContext = pkgs.runCommand "mcp-server-context" {} ''
    cp -r ${mcp-server-src} $out
    chmod -R u+w $out
    cp ${dockerignore} $out/.dockerignore
  '';
in
{
  virtualisation.quadlet = {
    builds= {
      mcp-server = {
          buildConfig = {
              tag = "localhost/mcp-server:latest";
              file = "${mcp-dockerfile}";
              workdir = "${buildContext}";
              pull = "missing";
          };
          serviceConfig = {
            TimeoutStartSec = 900;
          };

          unitConfig = {
            Description = "Build MCP Server OCI image";
          };
        };
      };

      containers = {
           mcp-server = {
        autoStart = false;

        containerConfig = {
          image = "localhost/mcp-server:latest";

          publishPorts = [
            "31415:31415"
          ];

          volumes = [
            "${config.xdg.configHome}/mcp-server/mcp-servers.json:/config/mcp-servers.json:ro,z"
            "/run/user/1000/podman/podman.sock:/var/run/docker.sock:z"
          ];

          networks = [ "portainer-net" ];

          securityLabelDisable = true;
        };

        serviceConfig = {
          Restart         = "always";
          TimeoutStartSec = 600;
        };

        unitConfig = {
          Description = "MCP Server - Model Context Protocol";
          After    = [
            "network-online.target"
            "podman.socket"
            "mcp-server-build.service"
          ];
          Requires = [
            "podman.socket"
            "mcp-server-build.service"
          ];
        };
        };
    };
  };
  xdg.configFile."mcp-server/mcp-servers.json" = {
    text = builtins.toJSON {
      servers = [
      ];
    };
  };
}
