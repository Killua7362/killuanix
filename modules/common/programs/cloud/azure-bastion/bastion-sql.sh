#!/usr/bin/env bash
# Forward the DA dev Oracle DB to a local port via Azure Bastion +
# a stage app VM as jump host.
#
# Why the indirection: Azure Bastion's IP-target tunnel
# (`--target-ip-address`) only allows ports 22 and 3389 — can't forward
# 1521 directly even though enableIpConnect=true and the bastion is
# Standard SKU. Workaround: bastion-tunnel into the stage's app-01 VM
# on port 22, then `ssh -L` over that to reach the Oracle host inside
# the VNet.
#
# Two processes here:
#   1. az network bastion tunnel  →  local SSH port (background)
#   2. ssh -L <oracle>:<oracle> -N user@127.0.0.1 -p <local-ssh-port>
# trap on EXIT/INT/TERM tears both down on Ctrl-C.
set -euo pipefail

read_secret() {
  local path="$1" name="$2"
  if [[ ! -r "$path" ]]; then
    echo "bastion-sql: sops secret ${name} unreadable at ${path}" >&2
    echo "Add it to secrets/personal.yaml and re-run scripts/nix_switch." >&2
    exit 1
  fi
  tr -d '\n' < "$path"
}

DEV_SUB="$(read_secret "@devSubFile@" azure/dev_subscription_id)"
BASTION_SUB="$(read_secret "@bastionSubFile@" azure/bastion_subscription_id)"
DA_USERNAME="$(read_secret "@usernameFile@" azure/bastion_username)"
ORACLE_HOST="$(read_secret "@oracleHostFile@" azure/oracle_host)"
ORACLE_PORT="$(read_secret "@oraclePortFile@" azure/oracle_port)"
ORACLE_USER="$(read_secret "@oracleUserFile@" azure/oracle_username)"
ORACLE_PASS_FILE="@oraclePassFile@"

BASTION_DEV="/subscriptions/${BASTION_SUB}/resourceGroups/daa-azure-bastion-non-prod-eastus-rg/providers/Microsoft.Network/bastionHosts/daa-azure-bastion-non-prod-eastus"

env_name="${1:-dev}"
if [[ "$env_name" != "dev" ]]; then
  echo "bastion-sql currently only supports 'dev'. Edit the script to add prod." >&2
  exit 1
fi
target_sub="$DEV_SUB"
target_bastion="$BASTION_DEV"

# Jump VM defaults to stage 1's app-01 (shared RG, reaches the Oracle
# host 10.55.46.132). Stage-specific dyn/admin URLs live on each
# stage's own VM and cross-stage routing may be blocked — override via
# BASTION_SQL_JUMP_STAGE=<1-6> to tunnel through a different stage's
# app-01 VM. Oracle SERVICE_NAME is still picked client-side in SQL
# Developer regardless of jump VM.
jump_stage="${BASTION_SQL_JUMP_STAGE:-1}"
if ! [[ "$jump_stage" =~ ^[1-6]$ ]]; then
  echo "BASTION_SQL_JUMP_STAGE must be 1-6 (got: $jump_stage)" >&2
  exit 1
fi
stage_pad=$(printf "%02d" "$jump_stage")
if [ "$jump_stage" -eq 1 ]; then
  jump_rg="bdsi-stageapplication-eastus-rg"
else
  jump_rg="bdsi-stageapplication${stage_pad}-eastus-rg"
fi
jump_vm_name="bdsi-stage${stage_pad}-app-01-vm"
jump_vm_id="/subscriptions/${DEV_SUB}/resourceGroups/${jump_rg}/providers/Microsoft.Compute/virtualMachines/${jump_vm_name}"

read -rp "Local Oracle port [${ORACLE_PORT}]: " local_port
local_port="${local_port:-$ORACLE_PORT}"

# Pick a random ephemeral port for the SSH leg of the tunnel.
local_ssh_port=$((20000 + RANDOM % 10000))

AZ_FLAGS=()
if [[ -n "${BASTION_SSH_DEBUG:-}" ]]; then
  AZ_FLAGS+=(--debug)
fi

AZ_RUN=(az)
if [[ -n "${BASTION_SSH_VIA_SOCKS:-}" ]]; then
  AZ_RUN=(proxychains4 -q -f "@proxychainsConf@" az)
  unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy
fi

copy_password() {
  if [[ ! -r "$ORACLE_PASS_FILE" ]]; then return 1; fi
  if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    wl-copy < "$ORACLE_PASS_FILE"; return 0
  fi
  if command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    xclip -selection clipboard < "$ORACLE_PASS_FILE"; return 0
  fi
  return 1
}

echo "[1/3] az account set --subscription ${target_sub}" >&2
"${AZ_RUN[@]}" account set --subscription "$target_sub" "${AZ_FLAGS[@]}"

echo "[2/3] Opening bastion tunnel to ${jump_vm_name} (ssh) on local :${local_ssh_port}" >&2
"${AZ_RUN[@]}" network bastion tunnel \
  --ids "$target_bastion" \
  --target-resource-id "$jump_vm_id" \
  --resource-port 22 \
  --port "$local_ssh_port" \
  "${AZ_FLAGS[@]}" &
TUNNEL_PID=$!

cleanup() {
  echo "Tearing down bastion tunnel (pid $TUNNEL_PID)" >&2
  kill "$TUNNEL_PID" 2>/dev/null || true
  wait "$TUNNEL_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Wait up to 60s for the tunnel listener to come up.
ready=0
for _ in $(seq 1 60); do
  if (exec 3<>/dev/tcp/127.0.0.1/"$local_ssh_port") 2>/dev/null; then
    exec 3<&-
    exec 3>&-
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" -ne 1 ]]; then
  echo "Bastion tunnel never came up on 127.0.0.1:${local_ssh_port}" >&2
  exit 1
fi

clipboard_status="not copied (no wl-copy/xclip or no display)"
if copy_password; then
  clipboard_status="copied to clipboard"
fi

cat >&2 <<EOF

[3/3] Bastion tunnel ready. Opening ssh -L into ${jump_vm_name}.
      Enter your DA password (${DA_USERNAME}) when prompted.

SQL Developer connection:
  Hostname     127.0.0.1
  Port         ${local_port}
  Service name beastg<N>   (set in SQL Developer to switch stages)
  Username     ${ORACLE_USER}
  Password     <${clipboard_status}>

Tunnel is stage-agnostic — change Service name in the client, tunnel stays up.

EOF

# SSH local-forward through the bastion tunnel. -N = no shell, just forward.
# Loopback connects (proxychains 'localnet' covers them), so no proxy needed.
SSH_LOG=ERROR
SSH_VERBOSE=()
if [[ -n "${BASTION_SQL_DEBUG:-}${BASTION_SSH_DEBUG:-}" ]]; then
  SSH_LOG=DEBUG
  SSH_VERBOSE=(-vvv)
fi

# Pre-bind sanity check: bail early with clear messages if either local
# port is already taken, rather than letting ssh die silently and the
# trap nuke the bastion tunnel.
port_in_use() {
  (exec 3<>/dev/tcp/127.0.0.1/"$1") 2>/dev/null && exec 3<&- 3>&-
}
if port_in_use "$local_port"; then
  echo "Port ${local_port} already in use locally. Rerun and pick a different Local Oracle port." >&2
  exit 1
fi

exec ssh \
  "${SSH_VERBOSE[@]}" \
  -F /dev/null \
  -L "${local_port}:${ORACLE_HOST}:${ORACLE_PORT}" \
  -N \
  -p "$local_ssh_port" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel="$SSH_LOG" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 \
  -o ConnectTimeout=30 \
  "${DA_USERNAME}@127.0.0.1"
