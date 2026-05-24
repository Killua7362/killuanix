#!/usr/bin/env bash
# Refresh the Azure CLI token through the boeingvpn-ui SOCKS tunnel so
# Conditional Access (53003) sees a Boeing source IP. Use this whenever
# bastion-ssh / bastion-sql fails with AADSTS53003.
#
# Requires boeingvpn-ui to be in the green (connected) state — ocproxy
# listening on 127.0.0.1:1080.
set -euo pipefail

# Hardcoded tenant for DigitalAviations / Boeing AAD.
TENANT="6362b077-fb81-4d5b-adf3-129cdb1b56cf"

unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy

if ! (exec 3<>/dev/tcp/127.0.0.1/1080) 2>/dev/null; then
  echo "bastion-login: SOCKS listener not up on 127.0.0.1:1080." >&2
  echo "Start boeingvpn-ui first (http://127.0.0.1:7777, Connect, wait for green)." >&2
  exit 1
fi
exec 3<&- 3>&-

PROXY=(proxychains4 -q -f "@proxychainsConf@")

echo "[1/2] az logout (clearing stale token)" >&2
"${PROXY[@]}" az logout || true

echo "[2/2] az login --use-device-code --tenant ${TENANT}" >&2
echo "      Copy the URL+code below, paste into chrome-socks (browser inside Boeing tunnel)." >&2
exec "${PROXY[@]}" az login \
  --use-device-code \
  --tenant "$TENANT" \
  --scope "https://management.core.windows.net//.default"
