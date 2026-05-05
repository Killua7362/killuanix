{...}: {
  # Provisioned ahead of any service consumer. sh-platform-starter-data-sql
  # exists, so a SQL-backed microservice is expected; this keeps the infra
  # ready without waiting on that landing.
  virtualisation.quadlet.containers.boeing-postgres = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/library/postgres:16";
      publishPorts = ["5432:5432"];
      volumes = ["boeing_pg_data:/var/lib/postgresql/data:z"];
      environments = {
        POSTGRES_USER = "boeing";
        POSTGRES_PASSWORD = "boeing";
        POSTGRES_DB = "boeing";
      };
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Boeing - PostgreSQL 16 (reserved for SQL-backed services)";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
