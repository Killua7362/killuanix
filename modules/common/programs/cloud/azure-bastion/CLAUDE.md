# Azure Bastion (DigitalAviations)

Home Manager module that installs `azure-cli` with the `ssh` extension and a `bastion-ssh` wrapper for connecting to DigitalAviations STG instances through Azure Bastion. Imported only by `chrollo/home-manager/home.nix` and `killua/home.nix` (the two hosts that do Boeing/DigitalAviations work).

## Files

| File | Purpose |
|---|---|
| `default.nix` | Builds `azure-cli.withExtensions [ssh bastion]` + two `pkgs.runCommand` wrappers (`bastion-ssh`, `bastion-sql`), proxychains-ng + SOCKS config, all gated by `pkgs.stdenv.isLinux`. Also installs `pkgs.sqlcl` (Oracle SQLcl CLI — `sql` on PATH) for saving SQLcl connections that the `oracle-sqlcl` MCP server (`../../dev/ai/oracle-sqlcl-mcp.nix`) reads from `~/.dbtools/connections.json`. Sets `home.sessionVariables.BASTION_SSH_VIA_SOCKS = "1"`. |
| `bastion-ssh.sh` | VM SSH wrapper. Reads DA username + 3 subscription UUIDs from sops files (substituted via `pkgs.replaceVars`). Sources its connect logic from the upstream DA `bastion-ssh.sh` runbook. |
| `bastion-sql.sh` | Oracle DB tunnel wrapper. Forwards `10.55.46.132:1521` (dev) to a local port via `az network bastion tunnel --target-ip-address`. Stage switching is via Oracle SERVICE_NAME (`beastg1..beastg6`) in the client, not via tunnel. |

## Sops secrets

All UUIDs and the dev username are read from sops files at runtime — the script is hardcoded-secret-free. Declared in `modules/common/sops.nix`:

| Key | What it is |
|---|---|
| `azure/bastion_username` | Your DigitalAviations username (used for `dev` connections; the prod cases hardcode service accounts like `jboss` / `endeca` / `oracle` / `monitor`). |
| `azure/dev_subscription_id` | `boeing-BDSIeCommerce-dev` subscription UUID. |
| `azure/prod_subscription_id` | `boeing-BDSIeCommerce-prod` subscription UUID. |
| `azure/bastion_subscription_id` | `daa-devops-prod` subscription UUID (hosts the bastion hosts themselves). |

Edit:

```bash
sops secrets/personal.yaml
# add under the top level:
#   azure:
#     bastion_username: <yourdausername>
#     dev_subscription_id: <uuid>
#     prod_subscription_id: <uuid>
#     bastion_subscription_id: <uuid>
```

If any secret is missing the wrapper exits with a clear message naming the missing key; HM activation itself fails earlier because sops-nix can't decrypt a declared-but-absent key.

## Routing through boeingvpn-ui SOCKS

`az network bastion ssh` opens a WebSocket tunnel via `websocket-client`, which **does not honor `HTTPS_PROXY=socks5h://...`** (only the REST half — `requests` — does). Result: setting `HTTPS_PROXY` alone gets auth/REST through SOCKS but the tunnel WebSocket attempts an HTTP CONNECT against ocproxy, fails immediately with `Connection to remote host was lost`.

Workaround: `BASTION_SSH_VIA_SOCKS=1` env var wraps `az` with `proxychains4 -q` (libc-level TCP redirection, library-agnostic). Uses a generated config at `${proxychainsConf}` pointing at `socks5 127.0.0.1 1080` (boeingvpn-ui's ocproxy listener).

```bash
# boeingvpn-ui must be connected first (green state on http://127.0.0.1:7777)
BASTION_SSH_VIA_SOCKS=1 bastion-ssh dev
```

Useful when full-tunnel GlobalProtect isn't running but you still need DA-network routing for Conditional Access (error 53003 from Azure AD).

## Why no dyn/admin / browser tunnel here

Previously bundled an `avd-chrome` browser + dynamic SOCKS (`ssh -D`) on the same tunnel to reach internal `10.55.*` dyn/admin URLs. Removed: each stage's `app-01` VM only routes within its own subnet, so dyn/admin URLs on other stages were unreachable from any single jump. AVD bypasses this by living in a management subnet with broader routes; replicating that from app VMs isn't viable. For dyn/admin work, keep using AVD.

`bastion-sql` keeps just the Oracle `-L 1521` forward, which works from any stage's app-01 because the DB host (`10.55.46.132`) is reachable cross-subnet.

## Non-secrets kept inline

The resource-group naming (`bdsi-stageapplication{NN}-eastus-rg`, `bdsi-prodapplication-eastus-rg`, etc.), bastion-host names (`daa-azure-bastion-...`), and the VM-role lookup tables live in `bastion-ssh.sh` directly — they are derived/published values, not secrets, and pulling them through sops would just add noise. Same goes for the prod service-account usernames.

## Runbook (per PDF)

1. GlobalProtect VPN connected (boeingvpn-ui handles this — see `../boeingvpn-ui/CLAUDE.md`).
2. `az login` — browser flow, pick DigitalAviations email, complete MFA. Select the **DEV** subscription (`1`).
3. `bastion-ssh dev` — prompts for stage env number + instance number.
4. Enter your DA password when prompted by SSH.
5. `su - jboss` then `cd /var/log/jboss/stg3/app1/` for app logs.

Steps from the PDF that **do not apply on NixOS** (and are intentionally skipped by this module): PowerShell profile setup, `Set-ExecutionPolicy`, `winget install`, `notepad $PROFILE`. The wrapper is on `$PATH` directly — no shell-rc sourcing needed.

## Integration

Imported by:

- `chrollo/home-manager/home.nix` (office host)
- `killua/home.nix` (handheld)

Not in `modules/cross-platform/default.nix` — macnix/archnix don't get azure-cli installed.
