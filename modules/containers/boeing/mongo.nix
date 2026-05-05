{...}: let
  # Repo-local mongo bootstrap scripts. Mounted read-only into the canonical
  # /docker-entrypoint-initdb.d/ path so mongo's entrypoint runs them on the
  # first boot of an empty data volume.
  mongoInitDir = "/home/killua/Documents/Boeing/modernization/sh-usermgmt-api/develop/mongo-init";
in {
  virtualisation.quadlet.containers.boeing-mongo = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/library/mongo:7.0";
      publishPorts = ["27017:27017"];
      volumes = [
        "boeing_mongo_data:/data/db:z"
        "${mongoInitDir}:/docker-entrypoint-initdb.d:ro,z"
      ];
      environments = {
        MONGO_INITDB_ROOT_USERNAME = "root";
        MONGO_INITDB_ROOT_PASSWORD = "root";
        MONGO_INITDB_DATABASE = "usermgmt";
      };
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Boeing - MongoDB 7.0 (sh-usermgmt-api backing store)";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
