#!/usr/bin/env bash
#
# gp-fastest-gateway.sh — rank GlobalProtect gateways by network latency.
#
# GP gateways are HTTPS endpoints. The official client picks a gateway by SSL
# response time + priority; openconnect does not. This script measures the TCP
# connect time (RTT to :443) to each gateway over several samples and prints
# them sorted fastest-first.
#
# We measure TCP connect, NOT the TLS handshake: Boeing's gateways require
# "unsafe legacy renegotiation" which modern OpenSSL refuses, so time_appconnect
# is always 0. TCP connect time is a clean round-trip-latency proxy regardless.
#
# NOTE: this measures *proximity/latency*, not throughput. The lowest-latency
# gateway is usually the right pick, but for a true bandwidth comparison you'd
# have to connect to each and run iperf3/speedtest through the tunnel.
#
# Usage:
#   ./gp-fastest-gateway.sh              # default 5 samples per gateway
#   SAMPLES=10 ./gp-fastest-gateway.sh   # more samples = steadier numbers
#   DEADLINE=10 ./gp-fastest-gateway.sh  # hard wall-clock cap (s) for the sweep
#   ./gp-fastest-gateway.sh --connect    # connect to fastest via openconnect after testing

set -euo pipefail

SAMPLES="${SAMPLES:-5}"
PORT="${PORT:-443}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-2}"   # per-curl TCP connect timeout (s)
DEADLINE="${DEADLINE:-20}"                # hard wall-clock cap (s) for whole sweep
CONNECT=0
[[ "${1:-}" == "--connect" ]] && CONNECT=1

# name<TAB>host<TAB>priority
GATEWAYS=$(cat <<'EOF'
Amsterdam E	ta.eu1.cbc.vpn.boeing.net	1
Amsterdam F	ta.eu2.cbc.vpn.boeing.net	3
Brisbane E	ta.au1.cbc.vpn.boeing.net	1
Melbourne E	ta.au2.cbc.vpn.boeing.net	1
Northwest E	ta.nw1.cbc.vpn.boeing.net	1
Northwest F	ta.nw2.cbc.vpn.boeing.net	3
Southeast 1	ta.se1.cbc.vpn.boeing.net	1
Southeast 2	ta.se2.cbc.vpn.boeing.net	3
Southwest E	ta.sw1.cbc.vpn.boeing.net	1
Southwest F	ta.sw2.cbc.vpn.boeing.net	3
Tokyo E	ta.as1.cbc.vpn.boeing.net	1
Tokyo F	ta.as2.cbc.vpn.boeing.net	3
EOF
)

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }

# measure_host HOST -> prints median TCP-connect time in ms, or "FAIL".
# Median (not mean) so one slow handshake — DNS warmup, transient loss —
# can't skew the result; the typical RTT wins.
measure_host() {
  local host="$1" url="https://$1:$PORT"
  local i t samples=()
  for ((i = 0; i < SAMPLES; i++)); do
    # time_connect = TCP handshake complete (seconds, float). We stop there:
    # --connect-timeout bounds it, and the TLS layer is irrelevant for latency.
    # curl exits non-zero on the TLS legacy-reneg failure, but -w has already
    # printed time_connect to stdout by then; `|| true` keeps that value.
    t=$(curl -ks --connect-timeout "$CONNECT_TIMEOUT" --max-time "$CONNECT_TIMEOUT" -o /dev/null -w '%{time_connect}' "$url" 2>/dev/null || true)
    # 0 means connect/TLS failed
    if [[ -n "$t" && "$t" != "0.000000" && "$t" != "0" ]]; then
      samples+=("$t")
    elif ((${#samples[@]} == 0 && i >= 1)); then
      # Two leading failures, no success yet -> host down; stop retrying.
      # (We don't bail on the FIRST failure: a cold DNS+TCP sample can exceed
      # the connect timeout on a healthy gateway; the warm 2nd attempt works.)
      break
    fi
  done
  if ((${#samples[@]} == 0)); then
    echo "FAIL"
  else
    # sort numerically, take middle element, convert s -> ms
    printf '%s\n' "${samples[@]}" | sort -n | awk '
      { v[NR] = $1 }
      END {
        n = NR
        if (n % 2) m = v[(n + 1) / 2]
        else       m = (v[n / 2] + v[n / 2 + 1]) / 2
        printf "%.1f", m * 1000
      }'
  fi
}

echo "Testing ${SAMPLES} samples/gateway (TCP connect to :${PORT}, ${DEADLINE}s cap)..."
echo

results=""   # "ms<TAB>name<TAB>host<TAB>prio<TAB>ok"
SECONDS=0    # bash builtin: seconds since assignment; our wall-clock timer
while IFS=$'\t' read -r name host prio; do
  [[ -z "$host" ]] && continue
  printf '  %-14s %-28s ' "$name" "$host" >&2
  if ((SECONDS >= DEADLINE)); then
    echo "skipped (deadline)" >&2
    results+=$'999999\t'"$name"$'\t'"$host"$'\t'"$prio"$'\tSKIP'$'\n'
    continue
  fi
  ms=$(measure_host "$host")
  if [[ "$ms" == "FAIL" ]]; then
    echo "unreachable" >&2
    results+=$'999999\t'"$name"$'\t'"$host"$'\t'"$prio"$'\tFAIL'$'\n'
  else
    echo "${ms} ms" >&2
    results+="$ms"$'\t'"$name"$'\t'"$host"$'\t'"$prio"$'\tOK'$'\n'
  fi
done <<< "$GATEWAYS"

echo
echo "=== Ranked (fastest first) ==="
printf '%-8s  %-14s  %-28s  %-8s  %s\n' "ms" "name" "host" "priority" "status"
echo "$results" | sort -t$'\t' -k1 -n | while IFS=$'\t' read -r ms name host prio st; do
  [[ -z "$host" ]] && continue
  disp="$ms"
  [[ "$st" != "OK" ]] && disp="-"
  printf '%-8s  %-14s  %-28s  %-8s  %s\n' "$disp" "$name" "$host" "$prio" "$st"
done

fastest=$(echo "$results" | sort -t$'\t' -k1 -n | grep -m1 $'\tOK$' || true)
if [[ -z "$fastest" ]]; then
  echo; echo "No gateway reachable from this network." >&2
  exit 1
fi
fastest_name=$(cut -f2 <<< "$fastest")
fastest_host=$(cut -f3 <<< "$fastest")
echo
echo ">>> Fastest: ${fastest_name} (${fastest_host})"

if ((CONNECT)); then
  echo ">>> Connecting via openconnect..."
  command -v openconnect >/dev/null || { echo "openconnect not found" >&2; exit 1; }
  exec sudo openconnect --protocol=gp "$fastest_host"
fi
