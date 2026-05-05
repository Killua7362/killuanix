{...}: {
  virtualisation.quadlet.containers.boeing-mongo-express = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/library/mongo-express:1.0.2";
      publishPorts = ["8181:8081"];
      environments = {
        ME_CONFIG_MONGODB_ADMINUSERNAME = "root";
        ME_CONFIG_MONGODB_ADMINPASSWORD = "root";
        # mongo-express resolves "boeing-mongo" via podman's built-in DNS on
        # the default network — both containers share the rootful podman
        # network, so the hostname matches the quadlet name.
        ME_CONFIG_MONGODB_URL = "mongodb://root:root@boeing-mongo:27017/?authSource=admin";
        ME_CONFIG_BASICAUTH_USERNAME = "admin";
        ME_CONFIG_BASICAUTH_PASSWORD = "admin";
      };
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Boeing - mongo-express UI for boeing-mongo";
      After = ["network-online.target" "podman.socket" "boeing-mongo.service"];
      Requires = ["podman.socket" "boeing-mongo.service"];
    };
  };
}
