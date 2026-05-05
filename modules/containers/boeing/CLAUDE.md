# Boeing modernization — local-dev infrastructure

Rootful podman quadlets backing the microservices in `~/Documents/Boeing/modernization/`. Replaces the per-repo `docker-compose.yml` files (still in tree but no longer the way infra is brought up). Imported unconditionally on both NixOS hosts (chrollo + killua) via `modules/containers/default.nix`.

**Boot policy:** all five quadlets are declared with `autoStart = false`, so they do NOT come up automatically at boot. Bring them up manually for the day's work via `just up` (from the Justfile at `~/Documents/Boeing/modernization/`) or `sudo systemctl start boeing-mongo.service boeing-redis.service boeing-postgres.service boeing-mongo-express.service boeing-redis-commander.service`. `just down` stops them. `Restart = always` still applies once a unit is started — that covers crash recovery, not boot.

## Files

| File | Container | Description |
|---|---|---|
| `default.nix` | — | Imports the five containers below. |
| `mongo.nix` | `boeing-mongo` | MongoDB 7.0 on `:27017` (root/root, default db `usermgmt`). Bind-mounts the repo's `sh-usermgmt-api/develop/mongo-init/` into `/docker-entrypoint-initdb.d/` so first-boot bootstrap runs automatically. |
| `mongo-express.nix` | `boeing-mongo-express` | Web UI on `:8181` (admin/admin). Talks to `boeing-mongo` over podman's built-in DNS. |
| `redis.nix` | `boeing-redis` | Redis 7-alpine on `:6379`, AOF persistence on (`redis-server --appendonly yes`). |
| `redis-commander.nix` | `boeing-redis-commander` | Web UI on `:8281`. Points at `boeing-redis:6379`. |
| `postgres.nix` | `boeing-postgres` | Postgres 16 on `:5432` (boeing/boeing, db `boeing`). Reserved for SQL-backed services that consume `sh-platform-starter-data-sql`; no service depends on it yet. |

## Ports & credentials

| Service | Port | Credentials |
|---|---|---|
| MongoDB | 27017 | root / root |
| mongo-express | 8181 | admin / admin |
| Redis | 6379 | — |
| redis-commander | 8281 | — |
| Postgres | 5432 | boeing / boeing |

Ports and credentials match `sh-usermgmt-api/develop/src/main/resources/application*.yml` so the service binds to this infra without code-side changes.

## Mongo bootstrap mechanics

The repo's compose ran a separate one-shot `mongo-init` container that `mongosh`'d into the main container. We replace that with a bind-mount into `/docker-entrypoint-initdb.d/`, which mongo's official entrypoint scans on the first boot of an empty `boeing_mongo_data` volume — running every `.js` and `.sh` file there. Same end state, fewer moving parts.

To re-run the bootstrap (after editing the JS, or after a destructive schema change):

```sh
sudo systemctl stop boeing-mongo.service boeing-mongo-express.service
sudo podman volume rm boeing_mongo_data
sudo systemctl start boeing-mongo.service boeing-mongo-express.service
```

The bind-mount path is hardcoded to `/home/killua/Documents/Boeing/modernization/sh-usermgmt-api/develop/mongo-init` in `mongo.nix`. The directory must exist before `nixos-rebuild switch` — if the worktree isn't checked out, the container will fail to start.

## Volumes

Declared in `modules/containers/default.nix` alongside the other shared volumes:

- `boeing_mongo_data` — `/data/db` in the mongo container
- `boeing_redis_data` — `/data` in the redis container
- `boeing_pg_data` — `/var/lib/postgresql/data` in the postgres container

## Build/run helper

The Java side (Maven build of `sh-platform-starter`, then `mvn spring-boot:run` of services consuming it) is driven by a `Justfile` at `~/Documents/Boeing/modernization/Justfile`, paired with a `flake.nix` + `.envrc` providing Java 25 + Maven via direnv. See that directory's tooling, not this module — `./boeing/` is strictly the database layer.

## Integration

Imported once via `modules/containers/default.nix` → both `chrollo/configuration.nix` and `killua/configuration.nix` pick it up through their existing imports of the containers tree.
