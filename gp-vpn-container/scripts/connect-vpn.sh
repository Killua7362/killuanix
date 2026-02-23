#!/bin/bash

echo "Connecting to GlobalProtect VPN..."

openconnect \
    --protocol=gp \
    --user=dj216f \
    --usergroup=gateway \
    https://ta.as2.cbc.vpn.boeing.net
