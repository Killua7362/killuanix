# Azure Bastion (DigitalAviations)

Home Manager module that installs `azure-cli` (with the `ssh` + `bastion` extensions) and the DB clients used against Azure Bastion for DigitalAviations STG work. Imported only by `chrollo/home-manager/home.nix` and `killua/home.nix` (the two hosts that do Boeing/DigitalAviations work).

The bastion helper scripts themselves **are not built by nix**. They live in the DotFiles submodule under `DotFiles/scripts/boeing/`, fronted by a single **`bastion` dispatcher** on PATH:

```
bastion ssh <dev|prod|migrate>   bastion sql   bastion pg   bastion cosmos   bastion login
```

`bastion <sub>` execs `DotFiles/scripts/boeing/bastion.d/bastion-<sub>` (auto-discovered — add a new `bastion.d/bastion-<x>` and `bastion x` just works). Only the top-level `bastion` is on PATH; the `bastion.d/` subscripts are not directly invocable. See `DotFiles/scripts/boeing/` for the scripts and their shared `bastion.d/_lib.sh` (`load_env`, `require_vars`, `make_pxconf`).

**Distro-agnostic secrets.** The scripts read all secrets from ONE env file — default `~/.config/azure-bastion.env`, override with `$BASTION_ENV_FILE` — sourced as shell (`KEY=value`). No sops/nix path is referenced at runtime, so the same scripts run on any Linux. This module renders that env file from the `azure/*` sops secrets via `sops.templates."azure-bastion.env"` at HM activation. On a non-nix host, hand-create the file from `DotFiles/scripts/boeing/bastion.d/azure-bastion.env.example`.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Installs `azure-cli.withExtensions [ssh bastion]` + the scripts' runtime deps (`proxychains-ng`, `openssh`), all gated by `pkgs.stdenv.isLinux`. Also installs `pkgs.sqlcl` (Oracle SQLcl CLI — `sql` on PATH) for the `oracle-sqlcl` MCP server (`../../dev/ai/oracle-sqlcl-mcp.nix`), `pkgs.jetbrains.datagrip`, the vendored `sqldeveloper`, and `pkgs.azure-storage-azcopy`. Renders `~/.config/azure-bastion.env` via `sops.templates` from the `azure/*` keys. Sets `home.sessionVariables.BASTION_SSH_VIA_SOCKS = "1"`. |

The scripts fronted by `bastion` (in `DotFiles/scripts/boeing/bastion.d/`):

| `bastion <sub>` | Script | Purpose |
|---|---|---|
| `ssh` | `bastion-ssh` | VM SSH. Three args: `dev` (stage 1-6 + role table), `prod` (service-account VM table), `migrate` (flat VM `bdce-migrationvm-dev-eastus-vm`). Sub/bastion: `prod` → prod, else dev. |
| `sql` | `bastion-sql` | Oracle DB tunnel (dev). `az network bastion tunnel` → jump VM → `ssh -L 1521`. Stage switch via Oracle SERVICE_NAME (`beastg1..beastg6`) in the client, not the tunnel. |
| `pg` | `bastion-pg` | Postgres twin of `sql` (`ssh -L` the Azure PG host). Target overridable via `PGHOST`/`PGPORT`/`LOCAL_PG_PORT`. |
| `cosmos` | `bastion-cosmos` | Cosmos gateway tunnel (`ssh -L :443`, forces gateway mode). Needs a `/etc/hosts` entry for SNI — see the script's banner. |
| `login` | `bastion-login` | Refreshes the `az` token through the boeingvpn-ui SOCKS tunnel (device-code) so Conditional Access sees a Boeing source IP. Use on AADSTS53003. No secrets. |

## Secrets — the env file

The scripts source `$BASTION_ENV_FILE` (default `~/.config/azure-bastion.env`) and `require_vars` the ones they need (missing → clear error). Vars and their sops sources:

| Env var | sops key (`modules/common/sops.nix`) | Used by |
|---|---|---|
| `AZURE_BASTION_USERNAME` | `azure/bastion_username` | ssh, sql, pg, cosmos |
| `AZURE_DEV_SUBSCRIPTION_ID` | `azure/dev_subscription_id` | ssh, sql, pg, cosmos |
| `AZURE_PROD_SUBSCRIPTION_ID` | `azure/prod_subscription_id` | ssh (prod) |
| `AZURE_BASTION_SUBSCRIPTION_ID` | `azure/bastion_subscription_id` | ssh, sql, pg, cosmos |
| `AZURE_ORACLE_HOST` / `_PORT` / `AZURE_ORACLE_USERNAME` | `azure/oracle_host` / `_port` / `_username` | sql |

`login` uses none (hardcoded tenant + proxychains only). `azure/oracle_password` was dropped from `sops.nix` — no script uses it since the SQL-Developer clipboard-copy was removed (the value still exists in `secrets/personal.yaml`; re-add the decl if you want it rendered).

On nix: edit the underlying secrets (`sops secrets/personal.yaml`, `azure:` block), then `nix_switch` re-renders the env file. On other Linux: `cp bastion.d/azure-bastion.env.example ~/.config/azure-bastion.env`, `chmod 600`, fill in.

## Routing through boeingvpn-ui SOCKS

`az network bastion ssh` opens a WebSocket tunnel via `websocket-client`, which **does not honor `HTTPS_PROXY=socks5h://...`** (only the REST half — `requests` — does). Setting `HTTPS_PROXY` alone gets auth/REST through SOCKS but the tunnel WebSocket attempts an HTTP CONNECT against ocproxy and fails with `Connection to remote host was lost`.

Workaround: `BASTION_SSH_VIA_SOCKS=1` (default-on via `home.sessionVariables`) wraps `az` with `proxychains4 -q` (libc-level TCP redirection, library-agnostic). `_lib.sh`'s `make_pxconf()` writes the config to a temp file (`mktemp`) pointing at `socks5 127.0.0.1 1080` (boeingvpn-ui's ocproxy listener).

```bash
# boeingvpn-ui must be connected first (green state on http://127.0.0.1:7777)
BASTION_SSH_VIA_SOCKS=1 bastion ssh dev   # (already the default; empty value = try direct)
```

Useful when full-tunnel GlobalProtect isn't running but you still need DA-network routing for Conditional Access (error 53003 from Azure AD).

## Why no dyn/admin / browser tunnel here

Previously bundled an `avd-chrome` browser + dynamic SOCKS (`ssh -D`) on the same tunnel to reach internal `10.55.*` dyn/admin URLs. Removed: each stage's `app-01` VM only routes within its own subnet, so dyn/admin URLs on other stages were unreachable from any single jump. AVD bypasses this by living in a management subnet with broader routes; replicating that from app VMs isn't viable. For dyn/admin work, keep using AVD.

`bastion sql` keeps just the Oracle `-L 1521` forward, which works from any stage's app-01 because the DB host (`10.55.46.132`) is reachable cross-subnet.

## Non-secrets kept inline

The resource-group naming (`bdsi-stageapplication{NN}-eastus-rg`, `bdsi-prodapplication-eastus-rg`, etc.), bastion-host names (`daa-azure-bastion-...`), and the VM-role lookup tables live in `DotFiles/scripts/boeing/bastion.d/bastion-ssh` directly — they are derived/published values, not secrets, and pulling them through sops would just add noise. Same goes for the prod service-account usernames.

## Runbook (per PDF)

1. GlobalProtect VPN connected (boeingvpn-ui handles this — see `../boeingvpn-ui/CLAUDE.md`).
2. `bastion login` (or `az login`) — device-code flow, pick DigitalAviations email, complete MFA.
3. `bastion ssh dev` — prompts for stage env number + instance number.
4. Enter your DA password when prompted by SSH.
5. `su - jboss` then `cd /var/log/jboss/stg3/app1/` for app logs.

Steps from the PDF that **do not apply on NixOS** (and are intentionally skipped): PowerShell profile setup, `Set-ExecutionPolicy`, `winget install`, `notepad $PROFILE`. `bastion` is on `$PATH` directly (via `DotFiles/scripts/boeing/`) — no shell-rc sourcing needed.

## Integration

Imported by:

- `chrollo/home-manager/home.nix` (office host)
- `killua/home.nix` (handheld)

Not in `modules/cross-platform/default.nix` — macnix/archnix don't get azure-cli installed.
