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
