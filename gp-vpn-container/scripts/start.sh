#!/bin/bash

mkdir -p /dev/net
[ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200

# Install system CA certificates
update-ca-certificates 2>/dev/null || true

# Setup Chrome NSS database
rm -rf /home/vpnuser/.pki/nssdb
mkdir -p /home/vpnuser/.pki/nssdb
certutil -d sql:/home/vpnuser/.pki/nssdb -N --empty-password

cd /usr/local/share/ca-certificates/
csplit -z -f boeing-cert- ./all-boeing-certs.pem '/BEGIN CERTIFICATE/' '{*}'

for f in boeing-cert-*; do mv "$f" "${f}.crt"; done

update-ca-certificates 2>/dev/null || true

# Import all CA certs from system store into Chrome
for cert in /usr/local/share/ca-certificates/*.crt; do
    [ -f "$cert" ] || continue
    
    # Split in case file has multiple certs
    TMPDIR=$(mktemp -d)
    csplit -z -f "$TMPDIR/c-" "$cert" '/BEGIN CERTIFICATE/' '{*}' 2>/dev/null
    
    for c in "$TMPDIR"/c-*; do
        IS_CA=$(openssl x509 -in "$c" -noout -text 2>/dev/null | grep "CA:TRUE" || true)
        if [ -n "$IS_CA" ]; then
            NAME=$(openssl x509 -in "$c" -noout -subject -nameopt multiline 2>/dev/null | grep commonName | sed 's/.*= //')
            certutil -d sql:/home/vpnuser/.pki/nssdb -A \
                -t "CT,C,C" \
                -n "${NAME:-imported-$(basename $c)}" \
                -i "$c" 2>/dev/null
        fi
    done
    rm -rf "$TMPDIR"
done

# Clear HSTS cache
rm -rf /home/vpnuser/.config/google-chrome/Default/TransportSecurity
rm -rf /home/vpnuser/.config/google-chrome/Default/Network/TransportSecurity

chown -R vpnuser:vpnuser /home/vpnuser

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
