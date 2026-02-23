{ pkgs, config, lib, ... }:
let
  # ── Scripts ──────────────────────────────────────────────────────────────────

  supervisord-conf = pkgs.writeText "supervisord.conf" ''
      [unix_http_server]
      file=/var/run/supervisor.sock

      [supervisorctl]
      serverurl=unix:///var/run/supervisor.sock

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

      [supervisord]
      nodaemon=true
      logfile=/var/log/supervisord.log

      [program:xvnc]
      command=Xtigervnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -AlwaysShared
      user=vpnuser
      environment=HOME="/home/vpnuser"
      autorestart=true
      priority=1

      [program:fluxbox]
      command=fluxbox
      user=vpnuser
      environment=DISPLAY=":1",HOME="/home/vpnuser"
      autorestart=true
      priority=2

      [program:novnc]
      command=websockify --web /usr/share/novnc/ 6080 localhost:5901
      autorestart=true
      priority=3

      [program:chromium]
      command=google-chrome --no-sandbox --disable-setuid-sandbox --disable-gpu --disable-dev-shm-usage --no-first-run --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
      user=vpnuser
      environment=DISPLAY=":1",HOME="/home/vpnuser"
      autostart=false
      autorestart=false
  '';

  start-sh = pkgs.writeText "start.sh" ''
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

      for f in boeing-cert-*; do mv "$f" "$\{f\}.crt"; done

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
                      -n "$\{NAME:-imported-$(basename $c)\}" \
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
  '';

  connect-vpn-sh = pkgs.writeText "connect-vpn.sh" ''
    #!/bin/bash

    echo "Connecting to GlobalProtect VPN..."

    openconnect \
        --protocol=gp \
        --user=dj216f \
        --usergroup=gateway \
        https://ta.as2.cbc.vpn.boeing.net
  '';

  start-chrome-sh = pkgs.writeText "start-chrome.sh" ''
    #!/bin/bash
    google-chrome --no-sandbox --disable-setuid-sandbox --disable-gpu --disable-dev-shm-usage --no-first-run --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
  '';

  # ── Dockerfile ───────────────────────────────────────────────────────────────

  gp-vpn-dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ubuntu:22.04

    ENV DEBIAN_FRONTEND=noninteractive

    RUN echo "root:root" | chpasswd

    RUN apt-get update && apt-get install -y \
        openconnect \
        tigervnc-standalone-server \
        novnc \
        websockify \
        supervisor \
        fluxbox \
        dbus-x11 \
        xdg-utils \
        ca-certificates \
        nano \
        curl \
        wget \
        gnupg \
        libnss3-tools \
        && rm -rf /var/lib/apt/lists/*

    RUN wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        && apt-get update \
        && apt-get install -y /tmp/chrome.deb \
        && rm /tmp/chrome.deb \
        && rm -rf /var/lib/apt/lists/*

    RUN useradd -m -s /bin/bash vpnuser

    COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
    COPY scripts/start.sh /start.sh
    COPY scripts/connect-vpn.sh /connect-vpn.sh
    COPY scripts/start-chrome.sh /start-chrome.sh
    RUN chmod +x /start.sh /connect-vpn.sh /start-chrome.sh

    EXPOSE 6080

    CMD ["/start.sh"]
  '';

  # ── Build context (assembled in the Nix store) ──────────────────────────────

  buildContext = pkgs.runCommand "gp-vpn-build-context" {} ''
    mkdir -p $out/scripts
    cp ${supervisord-conf}  $out/scripts/supervisord.conf
    cp ${start-sh}          $out/scripts/start.sh
    cp ${connect-vpn-sh}    $out/scripts/connect-vpn.sh
    cp ${start-chrome-sh}   $out/scripts/start-chrome.sh
  '';

  certsPath = "${config.xdg.configHome}/gp-vpn/all-boeing-certs.pem";

in
{
  virtualisation.quadlet = {

    # ── Image build ────────────────────────────────────────────────────────────
    builds = {
      gp-vpn = {
        buildConfig = {
          tag    = "localhost/gp-vpn:latest";
          file   = "${gp-vpn-dockerfile}";
          workdir = "${buildContext}";
          pull   = "missing";
        };

        serviceConfig = {
          TimeoutStartSec = 900;
        };

        unitConfig = {
          Description = "Build GP VPN Browser OCI image";
        };
      };
    };

    # ── Container ──────────────────────────────────────────────────────────────
    containers = {
      gp-vpn = {
        autoStart = false;

        containerConfig = {
          image = "localhost/gp-vpn:latest";

          publishPorts = [
            "6080:6080"
          ];

          volumes = [
            "gp-vpn-data:/home/vpnuser:z"
            "${certsPath}:/usr/local/share/ca-certificates/all-boeing-certs.pem:ro,z"
          ];

          addCapabilities = [
            "NET_ADMIN"
            "SYS_ADMIN"
          ];

          securityLabelDisable = true;

          podmanArgs = [
            "--security-opt=seccomp=unconfined"
            "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
          ];
        };

        serviceConfig = {
          Restart         = "always";
          TimeoutStartSec = 600;
        };

        unitConfig = {
          Description = "GP VPN Browser – GlobalProtect VPN with Chrome via noVNC";
          After = [
            "network-online.target"
            "gp-vpn-build.service"
          ];
          Requires = [
            "gp-vpn-build.service"
          ];
        };
      };
    };
  };
}
