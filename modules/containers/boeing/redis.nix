{...}: {
  virtualisation.quadlet.containers.boeing-redis = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/library/redis:7-alpine";
      publishPorts = ["6379:6379"];
      volumes = ["boeing_redis_data:/data:z"];
      # AOF persistence so cache state survives container restarts. Matches
      # the repo's docker-compose.yml command override.
      exec = "redis-server --appendonly yes";
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Boeing - Redis 7 (sh-platform-starter-cache backend)";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
