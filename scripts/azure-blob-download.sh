#!/usr/bin/env bash
# Download an Azure blob to this machine via a container-scoped SAS URL,
# routed through the boeingvpn-ui SOCKS listener (DA-network Conditional Access).
#
# Usage:
#   azure-blob-download.sh '<sas-url>' <blob-name> [output-file]
#
#   <sas-url>     The full container SAS URL you were given, quoted, e.g.
#                 'https://acct.blob.core.windows.net/migration-data?sp=racwdl&...&sig=...'
#   <blob-name>   Name of the blob inside that container to fetch.
#   [output-file] Local path to write. Defaults to ./<blob-name>'s basename.
#
# Prereqs:
#   - boeingvpn-ui connected (green @ http://127.0.0.1:7777 — SOCKS5 on 127.0.0.1:1080)
#   - SAS must grant read (sp= containing r)
#
# Note: ON the DA VM itself you do NOT need this script — the VM is inside the
# DA network, so a plain `curl -o out 'https://acct.blob.../container/blob?<token>'`
# works without proxychains.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $(basename "$0") '<sas-url>' <blob-name> [output-file]" >&2
  exit 1
fi

sas_url="$1"
blob_name="$2"
out="${3:-$(basename "$blob_name")}"

# Split the SAS URL into base (up to container) and token (after ?).
base="${sas_url%%\?*}"
token="${sas_url#*\?}"
[[ "$base" != "$token" ]] || { echo "error: SAS URL has no '?<token>' part" >&2; exit 1; }

# https://<account>.blob.core.windows.net/<container>[/...]
host="${base#https://}"; host="${host%%/*}"           # <account>.blob.core.windows.net
account="${host%%.*}"                                   # <account>
container="${base#https://"$host"/}"; container="${container%%/*}"

[[ -n "$account" && -n "$container" ]] || { echo "error: could not parse account/container from URL" >&2; exit 1; }

# Resolve the proxychains conf fresh (store path changes on every nix rebuild).
conf="$(ls /nix/store/*bastion-ssh.proxychains.conf 2>/dev/null | head -1)"
[[ -n "$conf" ]] || { echo "error: bastion proxychains conf not found in /nix/store" >&2; exit 1; }

# SOCKS env vars MUST be unset or proxychains+az tunnel breaks.
unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy

echo "account=$account container=$container blob=$blob_name -> $out" >&2
exec proxychains4 -q -f "$conf" \
  az storage blob download \
    --account-name "$account" \
    --container-name "$container" \
    --name "$blob_name" \
    --file "$out" \
    --sas-token "$token"
