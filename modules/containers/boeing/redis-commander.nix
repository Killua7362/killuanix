{...}: {
  virtualisation.quadlet.containers.boeing-redis-commander = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/rediscommander/redis-commander:latest";
      publishPorts = ["8281:8081"];
      environments = {
        REDIS_HOSTS = "local:boeing-redis:6379";
      };
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Boeing - redis-commander UI for boeing-redis";
      After = ["network-online.target" "podman.socket" "boeing-redis.service"];
      Requires = ["podman.socket" "boeing-redis.service"];
    };
  };
}
