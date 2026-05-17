#!/usr/bin/env bash
# trakt-auth.sh — one-shot Trakt OAuth device-flow bootstrap.
#
# Why: Glance's "upcoming movies/TV" widgets hit /calendars/my/... which need
# an OAuth Bearer token. Headless dashboards have no browser to redirect, so
# we use the device flow: this script asks Trakt for a user code, you type it
# at trakt.tv/activate from any browser, the script polls for the resulting
# token pair, and prints them out so you can paste them into sops.
#
# Prereqs:
#   1. Register an app at https://trakt.tv/oauth/applications
#      Redirect URI: urn:ietf:wg:oauth:2.0:oob
#      Permissions: at minimum /calendars/my (= "scrobble" perm covers it).
#   2. export TRAKT_CLIENT_ID=<the app's Client ID>
#      export TRAKT_CLIENT_SECRET=<the app's Client Secret>
#   3. `nix-shell -p curl jq` or have both on PATH.
#
# Usage:
#   TRAKT_CLIENT_ID=... TRAKT_CLIENT_SECRET=... ./scripts/trakt-auth.sh
#
# Then:
#   sops secrets/personal.yaml
#     trakt_api_key:      <client id>     # same as TRAKT_CLIENT_ID
#     trakt_access_token: <printed token>
#     trakt_username:     <your username>
#     tmdb_api_key:       <from themoviedb.org>
#   scripts/nix_switch
#
# Token lifetime: 3 months. Re-run this script to rotate when widgets start
# returning 401.

set -euo pipefail

: "${TRAKT_CLIENT_ID:?Set TRAKT_CLIENT_ID (Trakt OAuth app Client ID)}"
: "${TRAKT_CLIENT_SECRET:?Set TRAKT_CLIENT_SECRET (Trakt OAuth app Client Secret)}"

API="https://api.trakt.tv"

echo "==> Requesting device code…" >&2
device_resp="$(curl -fsS -X POST "$API/oauth/device/code" \
  -H 'Content-Type: application/json' \
  -d "{\"client_id\":\"$TRAKT_CLIENT_ID\"}")"

device_code="$(echo "$device_resp" | jq -r .device_code)"
user_code="$(echo "$device_resp"   | jq -r .user_code)"
verify_url="$(echo "$device_resp"  | jq -r .verification_url)"
interval="$(echo "$device_resp"    | jq -r .interval)"
expires_in="$(echo "$device_resp"  | jq -r .expires_in)"

cat <<EOF >&2

  ┌──────────────────────────────────────────────────────────┐
  │  Open: $verify_url
  │  Enter code:  $user_code
  │  Expires in: $expires_in seconds. Polling every ${interval}s…
  └──────────────────────────────────────────────────────────┘

EOF

while :; do
  sleep "$interval"
  http_status=0
  body="$(curl -sS -o /tmp/trakt-token.$$.json -w '%{http_code}' \
    -X POST "$API/oauth/device/token" \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"$device_code\",\"client_id\":\"$TRAKT_CLIENT_ID\",\"client_secret\":\"$TRAKT_CLIENT_SECRET\"}")" || true
  http_status="$body"
  case "$http_status" in
    200)
      echo >&2 "==> Approved."
      jq -r '"access_token:   \(.access_token)\nrefresh_token:  \(.refresh_token)\nexpires_in:     \(.expires_in)\ncreated_at:     \(.created_at)"' /tmp/trakt-token.$$.json
      rm -f /tmp/trakt-token.$$.json
      exit 0
      ;;
    400) echo -n "." >&2 ;;                         # pending
    404) echo >&2 "✗ device code not found"; exit 1 ;;
    409) echo >&2 "✗ already used"; exit 1 ;;
    410) echo >&2 "✗ expired — re-run the script"; exit 1 ;;
    418) echo >&2 "✗ denied by user"; exit 1 ;;
    429) echo >&2 "↻ slow down (rate limit), backing off"; sleep "$interval" ;;
    *)   echo >&2 "? unexpected HTTP $http_status — body:"; cat /tmp/trakt-token.$$.json >&2; exit 1 ;;
  esac
done
