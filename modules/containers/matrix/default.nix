# Matrix stack — Synapse homeserver + four mautrix bridges + Element Web.
#
# Topology (single host, no federation):
#
#                            ┌──────────────┐
#                            │ element-web  │ :8009 (host 127.0.0.1)
#                            └──────┬───────┘
#                                   │ HTTP
#                            ┌──────▼───────┐
#                            │   synapse    │ :8008 (host 127.0.0.1)
#                            └─┬──┬──┬──┬──┬┘
#       ┌──────────────────────┘  │  │  │  └─────────────────┐
#       │                ┌────────┘  │  └────┐               │
#       ▼                ▼           ▼       ▼               ▼
# ┌───────────┐  ┌──────────────┐ ┌───────┐ ┌───────────┐ ┌───────────┐
# │ telegram  │  │   whatsapp   │ │ meta- │ │ meta-     │ │ matrix-   │
# │ mautrix   │  │   mautrix    │ │ insta │ │ messenger │ │ postgres  │
# │ :29317    │  │   :29318     │ │ :29319│ │ :29320    │ │ 5432      │
# └─────┬─────┘  └──────┬───────┘ └───┬───┘ └─────┬─────┘ └─────▲─────┘
#       └───────────────┴─────────────┴───────────┘             │
#                                  └────────── PG ──────────────┘
#
# All inter-container traffic rides the `matrix-net` podman network (declared
# in modules/containers/default.nix). Only synapse:8008 and element-web:8009
# are mapped to the host, both bound to 127.0.0.1 — front them with
# `tailscale serve` to access from Element X on phone.
#
# Bootstrap order (systemd):
#   matrix-postgres-env  → matrix-postgres  → matrix-postgres-ready
#                                                    │
#         ┌──────────────────────────────────────────┤
#         ▼                                          ▼
#  synapse-generate (once) ──► synapse-overrides    mautrix-<name>-config (x4)
#         │                          │                          │
#         └──────────┬───────────────┘                          │
#                    ▼                                          ▼
#                synapse  ◄─────── waits on all 4 bridge configs
#                    │
#                    ▼
#               mautrix-<name>  (x4)
#
# Element-web is independent of bridges; only needs its config.json rendered.
#
# First-run user steps (NOT automated — see matrix/CLAUDE.md):
#   1. seed sops with all matrix_* keys
#   2. nixos-rebuild switch
#   3. podman exec synapse register_new_matrix_user -c /data/homeserver.yaml \
#        -c /etc/synapse/overrides.yaml -u akshay -a http://localhost:8008
#   4. open http://127.0.0.1:8009, log in, DM each bridge bot to authenticate
{...}: {
  imports = [
    ./postgres.nix
    ./synapse.nix
    ./element-web.nix
    ./bridges
  ];
}
