# Boeing modernization — local-dev infrastructure for the microservices
# under ~/Documents/Boeing/modernization/.
#
# Replaces the per-repo docker-compose.yml files (kept in tree but no longer
# the way infra is brought up) with rootful podman quadlets. Services do NOT
# autostart at boot — bring them up explicitly with `just up` from the
# Justfile at ~/Documents/Boeing/modernization/, or `sudo systemctl start
# boeing-mongo.service ...` directly.
#
# Containers (all on localhost):
#   - boeing-mongo            : MongoDB 7.0  on :27017  (root/root, db `usermgmt`)
#   - boeing-mongo-express    : web UI       on :8181   (admin/admin)
#   - boeing-redis            : Redis 7      on :6379   (no auth, AOF on)
#   - boeing-redis-commander  : web UI       on :8281
#   - boeing-postgres         : Postgres 16  on :5432   (boeing/boeing, db `boeing`)
#
# Ports/credentials match sh-usermgmt-api/develop/application*.yml so the
# service binds to this infra without any code-side changes.
#
# ── Mongo bootstrap ──
# The mongo container bind-mounts sh-usermgmt-api/develop/mongo-init/ into
# /docker-entrypoint-initdb.d/. Mongo's official entrypoint auto-runs every
# .js / .sh file there on the FIRST boot of an empty data volume. To re-run
# the bootstrap (e.g. after schema changes):
#
#   sudo systemctl stop boeing-mongo.service
#   sudo podman volume rm boeing_mongo_data
#   sudo systemctl start boeing-mongo.service
#
# Volumes (`boeing_mongo_data`, `boeing_redis_data`, `boeing_pg_data`) are
# declared in modules/containers/default.nix.
{...}: {
  imports = [
    ./mongo.nix
    ./mongo-express.nix
    ./redis.nix
    ./redis-commander.nix
    ./postgres.nix
  ];
}
