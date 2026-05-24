# Shared helpers sourced by bastion-{ssh,sql,login}.
# Not executable on its own.

CONFIG_FILE="${BASTION_CONFIG:-$HOME/.config/bastion/config}"

load_config() {
  if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "bastion: config file not readable: $CONFIG_FILE" >&2
    echo "Copy config.example to that path and fill in values." >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  set -a; source "$CONFIG_FILE"; set +a

  # Defaults baked into the script so user doesn't have to export them.
  # Mirrors the nix Home Manager `sessionVariables` defaults.
  # Override per-call with `BASTION_SSH_VIA_SOCKS= bastion-ssh ...` (empty)
  # to bypass SOCKS for one invocation.
  export BASTION_SSH_VIA_SOCKS="${BASTION_SSH_VIA_SOCKS:-1}"
  export HTTPS_PROXY=socks5h://127.0.0.1:1080
  export HTTP_PROXY=socks5h://127.0.0.1:1080
  : "${SOCKS_HOST:=127.0.0.1}"
  : "${SOCKS_PORT:=1080}"
  export SOCKS_HOST SOCKS_PORT
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "bastion: required config var $name is empty (in $CONFIG_FILE)" >&2
    exit 1
  fi
}

write_proxychains_conf() {
  local host="${SOCKS_HOST:-127.0.0.1}" port="${SOCKS_PORT:-1080}"
  local f
  f="$(mktemp -t bastion-proxychains.XXXXXX.conf)"
  cat > "$f" <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 $host $port
EOF
  echo "$f"
}

setup_az_run() {
  AZ_RUN=(az)
  if [[ -n "${BASTION_SSH_VIA_SOCKS:-}" ]]; then
    if ! command -v proxychains4 >/dev/null 2>&1; then
      echo "bastion: BASTION_SSH_VIA_SOCKS=1 but proxychains4 not installed." >&2
      echo "  sudo apt install proxychains4" >&2
      exit 1
    fi
    PROXYCHAINS_CONF="$(write_proxychains_conf)"
    AZ_RUN=(proxychains4 -q -f "$PROXYCHAINS_CONF" az)
    unset HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy
  fi
  AZ_FLAGS=()
  if [[ -n "${BASTION_SSH_DEBUG:-}" ]]; then
    AZ_FLAGS+=(--debug)
  fi
}
