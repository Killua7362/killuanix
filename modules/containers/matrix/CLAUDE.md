# Matrix stack — Synapse + mautrix bridges + Element Web

Private Matrix hub with Telegram / WhatsApp / Instagram / Messenger bridged into one client. Federation disabled. Reaches the world only through `tailscale serve` on the user's tailnet — no public HTTPS, no `.well-known`.

## Server identity

**`server_name = matrix.killua.local`** — hard-coded in `synapse.nix` and every bridge config. **Irreversible after first boot**: it's baked into the signing key, room IDs, user IDs, and every event hash. To change it later you must `sudo podman volume rm matrix_synapse_data` and re-register every account from scratch.

## Files

| File | Container | Description |
|---|---|---|
| `default.nix` | — | Imports below + ASCII topology diagram of the stack. |
| `postgres.nix` | `matrix-postgres` | Postgres 16, network-only (no host port). First-boot `init-matrix.sh` creates 5 roles/DBs (synapse + 4 bridges) from sops env. Companion `matrix-postgres-ready.service` polls `pg_isready` so downstream units gate on it. |
| `synapse.nix` | `synapse` | Homeserver on `127.0.0.1:8008`. `synapse-generate.service` runs `synapse generate` once on first boot to write `/data/homeserver.yaml` + signing key. `synapse-overrides.service` re-renders `/run/matrix-synapse/etc/overrides.yaml` every boot to swap defaults for postgres + appservice registrations. Synapse runs with `--config-path /data/homeserver.yaml --config-path /etc/synapse/overrides.yaml`. |
| `element-web.nix` | `element-web` | Element Web on `127.0.0.1:8009`. `element-web-config.service` renders `/run/element-web/config.json` pointing at the local Synapse. |
| `bridges/default.nix` | `mautrix-telegram`, `mautrix-whatsapp`, `mautrix-meta-instagram`, `mautrix-meta-messenger` | All four mautrix bridges. Per-bridge `mautrix-<name>-config.service` renders both the bridge's `config.yaml` (under `/run/mautrix-<name>/`) and the matching appservice registration (under `/var/lib/matrix-appservices/<name>.yaml`) using the same sops-stored `as_token`/`hs_token` pair — no `-g` round-trip needed. |

## Networking

- One podman network `matrix-net` (10.89.2.0/24), declared in `modules/containers/default.nix`.
- All inter-container traffic uses container-name DNS (`http://synapse:8008`, `matrix-postgres:5432`).
- Only `synapse:8008` and `element-web:8009` map to the host, both bound to `127.0.0.1`. Bridges are network-only.

## Boot order (systemd)

```
matrix-postgres-env
  └─► matrix-postgres
        └─► matrix-postgres-ready
              ├─► synapse-generate (sentinel-guarded, runs once)
              │     └─► synapse-overrides
              │           │
              ├─► mautrix-telegram-config        ┐
              ├─► mautrix-whatsapp-config        │
              ├─► mautrix-meta-instagram-config  │  (4 parallel)
              └─► mautrix-meta-messenger-config  ┘
                    │
                    ▼ (synapse waits on overrides + all 4 -config services)
                  synapse
                    ├─► mautrix-telegram
                    ├─► mautrix-whatsapp
                    ├─► mautrix-meta-instagram
                    └─► mautrix-meta-messenger

element-web-config  ─►  element-web   (parallel, independent of synapse boot)
```

## sops secrets

Declared in `modules/common/sops-system.nix`. Per-host you must populate each value in `secrets/personal.yaml` before the first `nixos-rebuild switch`, or the env-staging services will produce empty env values and bridges will fail.

```
matrix_postgres_password              # postgres superuser password
matrix_synapse_db_password            # synapse role password
matrix_synapse_registration_secret    # synapse admin-API registration token

matrix_bridge_<name>_db_password      # postgres role password (per bridge)
matrix_bridge_<name>_as_token         # 32-byte hex, shared with synapse appservice registration
matrix_bridge_<name>_hs_token         # 32-byte hex, shared with synapse appservice registration
matrix_bridge_<name>_pickle_key       # local key for bridge's olm session storage (lose = lose E2EE history)

matrix_bridge_telegram_api_id         # int, from https://my.telegram.org
matrix_bridge_telegram_api_hash       # hex string, from https://my.telegram.org
```

Where `<name>` ∈ `{telegram, whatsapp, meta_instagram, meta_messenger}` (note: underscores in secret names, dashes in container names).

### Generating tokens

Token-like secrets are arbitrary high-entropy values. The user generates them once and never rotates:

```sh
openssl rand -hex 32   # for as_token / hs_token / pickle_key / registration_secret
openssl rand -base64 24 | tr -d '=+/'   # alternative for db_password
```

Then edit `secrets/personal.yaml` with `sops secrets/personal.yaml` and add the keys.

### Telegram api credentials

Visit https://my.telegram.org → log in → "API development tools" → create app. Copy `api_id` (integer) and `api_hash` (32-char hex) into sops.

## Two-host caveat

Module is imported via `modules/containers/default.nix`, which both `killua` and `chrollo` pick up. Each host gets its own **independent** signing key, postgres volume, and bridge sessions — two distinct homeservers that happen to share the `matrix.killua.local` string.

Since federation is off and the hosts never talk Matrix-to-Matrix, this is harmless — only ever log into one of them as your daily-driver homeserver.

## Autostart: off

All matrix containers ship with **`autoStart = false`** on both hosts. The stack is heavy (7 containers, ~1.5GB RAM idle, busy backfill) so we don't pay the cost at every boot. Bring it up manually when you want to chat:

```sh
sudo systemctl start synapse           # cascades postgres + overrides + bridges-config via Requires
sudo systemctl start element-web \
    mautrix-telegram \
    mautrix-whatsapp \
    mautrix-meta-instagram \
    mautrix-meta-messenger
```

Stop the whole stack:

```sh
sudo systemctl stop synapse element-web matrix-postgres \
    mautrix-telegram mautrix-whatsapp mautrix-meta-instagram mautrix-meta-messenger
```

If you want one host (e.g. killua) to autostart while chrollo stays manual, gate the import in `modules/containers/default.nix` behind `lib.mkIf (config.networking.hostName == "killua")` rather than flipping per-container.

## First-run user steps (NOT automated)

After the first successful `sudo scripts/nix_switch`:

1. **Create your Matrix account.**
   ```sh
   sudo podman exec -it synapse register_new_matrix_user \
       -c /data/homeserver.yaml \
       -c /etc/synapse/overrides.yaml \
       -u akshay \
       -a http://localhost:8008
   ```
   It will prompt for password and (y/n) admin. The user/admin mxid must match the one in `bridges/default.nix` (`@akshay:matrix.killua.local`) for admin-level bridge commands.

2. **Log in to Element Web** at `http://127.0.0.1:8009`. The homeserver autofills as `matrix.killua.local`.

3. **Authenticate each bridge** by DM-ing its bot:
   | Bridge | Bot mxid | Login flow |
   |---|---|---|
   | Telegram | `@telegrambot:matrix.killua.local` | `login <phone_with_country_code>` → enter SMS code Telegram sends |
   | WhatsApp | `@whatsappbot:matrix.killua.local` | `login qr` → scan the QR ASCII the bot drops into the chat |
   | Instagram | `@instagrambot:matrix.killua.local` | `login` then follow the cookie-extraction flow in https://docs.mau.fi/bridges/go/meta/authentication.html |
   | Messenger | `@messengerbot:matrix.killua.local` | same as Instagram, but with a Facebook cookie |

4. **Expose to phone via Tailscale (optional).** Synapse only listens on `127.0.0.1`; to reach Element X on mobile add a Tailscale serve mapping:
   ```sh
   sudo tailscale serve --bg --https=443 http://127.0.0.1:8008
   ```
   Then point Element X at `https://<killua-magicdns>`. Run a second `--set-path=/element …8009` if you also want Element Web available remotely.

## Backups (manual; out of scope here but important)

The `matrix_synapse_data` volume contains the signing key and full room state including E2EE keys. The four `mautrix_<bridge>_data` volumes contain Telegram/WhatsApp/Meta session state — lose these and you must re-authenticate every bridge.

```sh
sudo podman volume export matrix_synapse_data -o /backup/matrix_synapse_$(date +%F).tar
# repeat for each mautrix_*_data
```

Restore: `podman volume import <name> /backup/<file>.tar` while the container is stopped.

## Common pitfalls

- **`server_name` mismatch.** The string `matrix.killua.local` lives in `synapse.nix`, `element-web.nix`, and `bridges/default.nix`. Don't change one without the others. If you want to swap to your tailnet hostname, do it before first boot.
- **Synapse won't start: "missing appservice file".** A bridge's `-config.service` failed. Check `journalctl -u mautrix-telegram-config -n 50`. Most common cause: a sops secret is missing or empty — the cat-from-sopsPath script will succeed but produce a blank `as_token`, then synapse rejects the registration.
- **Bridges show "Login required" but you're already logged in.** Pickle key changed. Don't rotate `matrix_bridge_<name>_pickle_key` after first auth without expecting to re-log into the remote service.
- **Telegram bridge says `BadRequestError: API_ID_INVALID`.** Wrong api_id (must be the integer from my.telegram.org, not the api_hash). Check sops.
- **Element X mobile can't reach `http://192.168.x.x:8008`.** Element X requires HTTPS in production. Use `tailscale serve --https` to terminate TLS on the tailnet.

## Integration

Imported once via `modules/containers/default.nix` → both `chrollo/configuration.nix:17` and `killua/configuration.nix:21` pick it up through their existing imports of the containers tree. Volumes (`matrix_postgres_data`, `matrix_synapse_data`, `mautrix_*_data`) and the `matrix-net` podman network are declared alongside other shared resources in `modules/containers/default.nix`.
