#!/bin/bash

# Backup DNS and default route
cp /etc/resolv.conf /etc/resolv.conf.pre-vpn
DEFAULT_GW=$(ip route show default | head -1)

cleanup() {
    echo ""
    echo "=== Cleaning up VPN ==="

    # Restore DNS
    echo "Restoring DNS..."
    cp /etc/resolv.conf.pre-vpn /etc/resolv.conf

    # Remove any leftover tun interfaces
    for tun in $(ip link show type tun 2>/dev/null | grep -oP '^\d+: \K[^:]+'); do
        echo "Removing interface $tun..."
        ip link delete "$tun" 2>/dev/null
    done

    # Restore default route if missing
    if ! ip route show default | grep -q .; then
        echo "Restoring default route: $DEFAULT_GW"
        ip route add $DEFAULT_GW 2>/dev/null
    fi

    echo "=== Cleanup complete ==="
}

trap cleanup EXIT

# Keep openconnect in the FOREGROUND so it can read passwords from stdin
openconnect \
    --protocol=gp \
    --user=dj216f \
    --usergroup=gateway \
    https://ta.as2.cbc.vpn.boeing.net
