#!/bin/bash

cp /etc/resolv.conf /etc/resolv.conf.pre-vpn

cleanup() {
    echo "Restoring DNS..."
    cp /etc/resolv.conf.pre-vpn /etc/resolv.conf
}
trap cleanup EXIT INT TERM HUP

openconnect \
    --protocol=gp \
    --user=dj216f \
    --usergroup=gateway \
    https://ta.as2.cbc.vpn.boeing.net
