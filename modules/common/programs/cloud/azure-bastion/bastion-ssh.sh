#!/usr/bin/env bash
# Connect to DigitalAviations dev/prod VMs through Azure Bastion.
#
# Adapted from the upstream `bastion-ssh.sh` runbook (sourced into ~/.bashrc).
# Differences:
#   - Shipped as a standalone executable (PATH-resolved via Home Manager),
#     not a bash function that needs sourcing.
#   - All subscription UUIDs + the dev username come from sops files,
#     not hardcoded constants. Declared in modules/common/sops.nix.
#   - Resource-group naming, bastion paths, VM-role tables: unchanged
#     (not secrets, derived from the subscription UUIDs).
set -euo pipefail

read_secret() {
  local path="$1" name="$2"
  if [[ ! -r "$path" ]]; then
    echo "bastion-ssh: sops secret ${name} unreadable at ${path}" >&2
    echo "Add it to secrets/personal.yaml and re-run scripts/nix_switch." >&2
    exit 1
  fi
  tr -d '[:space:]' < "$path"
}

DEV_SUB="$(read_secret "@devSubFile@" azure/dev_subscription_id)"
PROD_SUB="$(read_secret "@prodSubFile@" azure/prod_subscription_id)"
BASTION_SUB="$(read_secret "@bastionSubFile@" azure/bastion_subscription_id)"
DEV_USERNAME="$(read_secret "@usernameFile@" azure/bastion_username)"

BASTION_DEV="/subscriptions/${BASTION_SUB}/resourceGroups/daa-azure-bastion-non-prod-eastus-rg/providers/Microsoft.Network/bastionHosts/daa-azure-bastion-non-prod-eastus"
BASTION_PROD="/subscriptions/${BASTION_SUB}/resourceGroups/daa-azure-bastion-eastus-rg/providers/Microsoft.Network/bastionHosts/daa-azure-bastion-eastus"

# Stage 1 uses the shared RG; stages 2-6 each get their own numbered RG.
_dev_vm_id() {
  local stage_pad rg
  stage_pad=$(printf "%02d" "$1")
  if [ "$1" -eq 1 ]; then
    rg="bdsi-stageapplication-eastus-rg"
  else
    rg="bdsi-stageapplication${stage_pad}-eastus-rg"
  fi
  echo "/subscriptions/${DEV_SUB}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/bdsi-stage${stage_pad}-${2}-vm"
}

_prod_vm_id() {
  echo "/subscriptions/${PROD_SUB}/resourceGroups/${1}/providers/Microsoft.Compute/virtualMachines/bdsi-prod-${2}-vm"
}

env_name="${1:-}"
if [ -z "$env_name" ]; then
  echo "Usage: bastion-ssh <dev|prod|migrate>" >&2
  exit 1
fi

vm_id=""
username=""

case "$env_name" in
  dev)
    read -rp "Enter stage number (1-6): " input
    if ! [[ "$input" =~ ^[1-6]$ ]]; then
      echo "Invalid. Enter a number 1-6." >&2
      exit 1
    fi

    echo "Available VMs: app1, app2, aux1, merch1, preview1"
    read -rp "Enter VM name: " vm_name

    vm_role=""
    case "$vm_name" in
      app1) vm_role="app-01" ;;
      app2) vm_role="app-02" ;;
      aux1) vm_role="aux-01" ;;
      merch1) vm_role="merch-01" ;;
      preview1) vm_role="preview-01" ;;
      *)
        echo "Invalid VM. Choose from: app1, app2, aux1, merch1, preview1" >&2
        exit 1
        ;;
    esac

    vm_id=$(_dev_vm_id "$input" "$vm_role")
    username="$DEV_USERNAME"
    echo "Connecting to dev - stage${input} - ${vm_name} as ${username}..."
    ;;

  prod)
    app_rg="bdsi-prodapplication-eastus-rg"
    db_rg="bdsi-proddatabase-eastus-rg"
    mon_rg="bdsi-prodmonitoring-eastus-rg"

    echo "Available VMs: app1-6, aux1-3, bcc, search, itl, db1, db2, monitoring"
    read -rp "Enter VM name: " vm_name

    case "$vm_name" in
      app1) vm_id=$(_prod_vm_id "$app_rg" "app-01"); username="jboss" ;;
      app2) vm_id=$(_prod_vm_id "$app_rg" "app-02"); username="jboss" ;;
      app3) vm_id=$(_prod_vm_id "$app_rg" "app-03"); username="jboss" ;;
      app4) vm_id=$(_prod_vm_id "$app_rg" "app-04"); username="jboss" ;;
      app5) vm_id=$(_prod_vm_id "$app_rg" "app-05"); username="jboss" ;;
      app6) vm_id=$(_prod_vm_id "$app_rg" "app-06"); username="jboss" ;;
      aux1) vm_id=$(_prod_vm_id "$app_rg" "aux-01"); username="jboss" ;;
      aux2) vm_id=$(_prod_vm_id "$app_rg" "aux-02"); username="jboss" ;;
      aux3) vm_id=$(_prod_vm_id "$app_rg" "aux-03"); username="jboss" ;;
      bcc) vm_id=$(_prod_vm_id "$app_rg" "tools-01"); username="jboss" ;;
      search) vm_id=$(_prod_vm_id "$app_rg" "search-01"); username="endeca" ;;
      itl) vm_id=$(_prod_vm_id "$app_rg" "itl-01"); username="endeca" ;;
      db1) vm_id=$(_prod_vm_id "$db_rg" "db-01"); username="oracle" ;;
      db2) vm_id=$(_prod_vm_id "$app_rg" "db-02"); username="oracle" ;;
      monitoring) vm_id=$(_prod_vm_id "$mon_rg" "monitoring-01"); username="monitor" ;;
      *)
        echo "Invalid VM. Choose from: app1-6, aux1-3, bcc, search, itl, db1, db2, monitoring" >&2
        exit 1
        ;;
    esac

    echo "Connecting to prod - ${vm_name} as ${username}..."
    ;;

  migrate)
    # Migration VM — flat resource, no stage pattern. Dev subscription +
    # non-prod bastion, DA username (same as dev).
    vm_id="/subscriptions/${DEV_SUB}/resourceGroups/bdce-migrationvm-dev-eastus-rg/providers/Microsoft.Compute/virtualMachines/bdce-migrationvm-dev-eastus-vm"
    username="$DEV_USERNAME"
    echo "Connecting to migrate - bdce-migrationvm as ${username}..."
    ;;

  *)
    echo "Invalid environment. Use 'dev', 'prod', or 'migrate'." >&2
    exit 1
    ;;
esac

if [ "$env_name" = "prod" ]; then
  target_sub="$PROD_SUB"
  target_bastion="$BASTION_PROD"
else
  target_sub="$DEV_SUB"
  target_bastion="$BASTION_DEV"
fi

AZ_FLAGS=()
if [[ -n "${BASTION_SSH_DEBUG:-}" ]]; then
  AZ_FLAGS+=(--debug)
fi

# When BASTION_SSH_VIA_SOCKS=1, wrap az with proxychains4 so ALL TCP
# (including the WebSocket tunnel — which azure-cli's websocket-client
# can't route through HTTPS_PROXY=socks5h://...) goes through the
# boeingvpn-ui SOCKS5 listener at 127.0.0.1:1080. requires the SOCKS
# listener to be up first (start boeingvpn-ui and wait for the green
# state).
AZ_RUN=(az)
if [[ -n "${BASTION_SSH_VIA_SOCKS:-}" ]]; then
  AZ_RUN=(proxychains4 -q -f "@proxychainsConf@" az)
  # CRITICAL: unset HTTPS_PROXY/HTTP_PROXY. proxychains hijacks the
  # connect() syscall at libc level — if HTTPS_PROXY is also set,
  # websocket-client tries to do an HTTP CONNECT through the SOCKS
  # listener (treating socks5h:// as if it were http://), which
  # ocproxy replies to with raw SOCKS handshake bytes → instant
  # `Connection to remote host was lost`.
  unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy
fi

echo "[1/2] az account set --subscription ${target_sub}" >&2
"${AZ_RUN[@]}" account set --subscription "$target_sub" "${AZ_FLAGS[@]}"

echo "[2/2] az network bastion ssh --> ${vm_id}" >&2
exec "${AZ_RUN[@]}" network bastion ssh \
  --ids "$target_bastion" \
  --target-resource-id "$vm_id" \
  --auth-type password \
  --username "$username" \
  "${AZ_FLAGS[@]}"
