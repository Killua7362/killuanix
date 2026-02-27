#!/bin/bash
# Monitors connectivity and restarts networking if needed
while true; do
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        echo "[watchdog] Network down — attempting recovery..."
        # Flush and re-request DHCP / restart networking
        ip link set eth0 down 2>/dev/null
        ip link set eth0 up 2>/dev/null
        # Re-populate resolv.conf if needed
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    fi
    sleep 10
done