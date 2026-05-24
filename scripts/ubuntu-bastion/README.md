# bastion-ssh / bastion-sql on Ubuntu

Portable port of the nix-managed `bastion-ssh`, `bastion-sql`, and `bastion-login` wrappers. Same behavior as the Home Manager versions in `modules/common/programs/cloud/azure-bastion/`, but driven by a plain text config file instead of sops.

## What you get

| Command | Does |
|---|---|
| `bastion-ssh dev` | Prompts for stage (1-6) + VM (app1/app2/aux1/merch1/preview1), opens `az network bastion ssh` to that VM as your DA user. |
| `bastion-ssh prod` | Prompts for VM name, connects with the matching service account (jboss/endeca/oracle/monitor). |
| `bastion-sql dev` | Opens a bastion SSH tunnel to a stage's `app-01` VM, then `ssh -L <port>:<oracle-host>:1521` so SQL Developer / DataGrip / sqlcl can hit `127.0.0.1:1521`. Stage switching is via Oracle SERVICE_NAME (`beastg1..beastg6`) client-side. |
| `bastion-login` | `az logout && az login --use-device-code` routed through a SOCKS proxy. Use when AAD throws AADSTS53003 because Conditional Access doesn't see a Boeing IP. |

## Install

```bash
git clone <this repo>   # or just copy the scripts/ubuntu-bastion/ dir
cd scripts/ubuntu-bastion
./install.sh
```

`install.sh` does:

1. apt installs `openssh-client`, `proxychains4`, `xclip`, plus the Microsoft keyring + `azure-cli`.
2. `az extension add` for `ssh` and `bastion`.
3. Copies the three commands + `lib-common.sh` to `~/.local/bin`.
4. Drops a `~/.config/bastion/config` skeleton (mode 600) if none exists.

If `~/.local/bin` isn't on `$PATH`, add it to `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Configure

Edit `~/.config/bastion/config`. Keep mode `600`.

Required:

- `BASTION_USERNAME` — your DigitalAviations username.
- `DEV_SUBSCRIPTION_ID` — `boeing-BDSIeCommerce-dev` UUID.
- `PROD_SUBSCRIPTION_ID` — `boeing-BDSIeCommerce-prod` UUID.
- `BASTION_SUBSCRIPTION_ID` — `daa-devops-prod` UUID (hosts the bastion resources).
- `ORACLE_HOST` — DB private IP (default `10.55.46.132` for dev).
- `ORACLE_PORT` — `1521`.
- `ORACLE_USERNAME` — DB user.

Optional:

- `ORACLE_PASSWORD_FILE` — path to a plain file with the Oracle password; `bastion-sql` copies it to the clipboard via `wl-copy` / `xclip` / `xsel`. Recommend `chmod 600`.
- `BASTION_SSH_VIA_SOCKS=1` — wrap `az` with `proxychains4` pointing at `SOCKS_HOST:SOCKS_PORT` (default `127.0.0.1:1080`). Needs an external SOCKS5 listener already running (ocproxy, ssh -D, openconnect, etc.). Required if Conditional Access blocks non-Boeing IPs.
- `SOCKS_HOST`, `SOCKS_PORT` — override the SOCKS target.
- `TENANT` — Azure AD tenant for `bastion-login`. Default is hardcoded to DigitalAviations.

## Use

```bash
# Plain login (browser flow; works if Conditional Access lets your IP through):
az login
az account set --subscription "<dev-sub-uuid>"

# Or, behind Conditional Access — bring up a SOCKS tunnel first, then:
BASTION_SSH_VIA_SOCKS=1 bastion-login

# SSH into a dev VM:
bastion-ssh dev          # prompts for stage + VM

# Prod:
bastion-ssh prod         # prompts for VM, uses service-account user

# Oracle DB tunnel for SQL Developer / DataGrip / sqlcl:
bastion-sql dev          # prompts for local port (default 1521)
# Connect client to 127.0.0.1:1521, SERVICE_NAME=beastg<N>
```

Per-call env vars:

- `BASTION_SSH_VIA_SOCKS=1` — force SOCKS routing for one call (also settable in config).
- `BASTION_SSH_VIA_SOCKS=` (empty) — bypass SOCKS for one call.
- `BASTION_SQL_JUMP_STAGE=<1-6>` — choose which stage's `app-01` is the SSH jump (default 1). Oracle SERVICE_NAME selects the actual stage's DB schema regardless.
- `BASTION_SSH_DEBUG=1` / `BASTION_SQL_DEBUG=1` — verbose `az --debug` + `ssh -vvv`.

## SOCKS routing (Conditional Access workaround)

`az network bastion ssh` opens a WebSocket tunnel using `websocket-client`, which does **not** honor `HTTPS_PROXY=socks5h://...`. Setting `HTTPS_PROXY` alone gets the REST half through SOCKS but the tunnel WebSocket fails with `Connection to remote host was lost`.

Fix: `BASTION_SSH_VIA_SOCKS=1` wraps `az` with `proxychains4 -q` (libc-level TCP redirection, library-agnostic). The scripts unset every `*_PROXY` env var before invoking `az` so the two mechanisms don't fight.

You need a SOCKS5 listener already up. Options:

- `ocproxy` driven by `openconnect` against a Boeing GlobalProtect/AnyConnect gateway.
- `ssh -D 1080` to any reachable host on the corporate network.
- Any third-party VPN client that exposes a SOCKS proxy.

## Prod VM table

`bastion-ssh prod` maps VM short names → resource group + service account:

| Short | Resource group | Service user |
|---|---|---|
| `app1`..`app6`, `aux1`..`aux3`, `bcc` | `bdsi-prodapplication-eastus-rg` | `jboss` |
| `search` | `bdsi-prodapplication-eastus-rg` | `endeca` |
| `itl` | `bdsi-prodapplication-eastus-rg` | `endeca` |
| `db1` | `bdsi-proddatabase-eastus-rg` | `oracle` |
| `db2` | `bdsi-prodapplication-eastus-rg` | `oracle` |
| `monitoring` | `bdsi-prodmonitoring-eastus-rg` | `monitor` |

## Troubleshooting

- **`AADSTS53003 — blocked by Conditional Access`**: bring up SOCKS, then `BASTION_SSH_VIA_SOCKS=1 bastion-login`. Re-run the bastion command with `BASTION_SSH_VIA_SOCKS=1`.
- **`Connection to remote host was lost` right after auth**: you set `HTTPS_PROXY=socks5h://...` instead of using `BASTION_SSH_VIA_SOCKS=1`. Unset all `*_PROXY` and use the wrapper.
- **`Bastion tunnel never came up`** (bastion-sql): the bastion didn't open the listener in 60s. Often a stale `az` token — try `az logout && az login`. If behind Conditional Access, use `bastion-login`.
- **`Port 1521 already in use`** (bastion-sql): something else is bound locally. Rerun and pick another port; update the client connection accordingly.
- **`proxychains4: command not found`**: `sudo apt install proxychains4`.

## Where this differs from the nix version

- Config lives at `~/.config/bastion/config` (plain text, mode 600) instead of sops-decrypted runtime paths.
- `proxychains4.conf` is generated at runtime in `$TMPDIR` (the nix version uses a store path).
- No automatic `BASTION_SSH_VIA_SOCKS=1` default — opt in per call or in config.
- Doesn't ship SQL Developer / DataGrip / sqlcl — install those separately as you need.
