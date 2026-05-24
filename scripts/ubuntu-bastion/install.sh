#!/usr/bin/env bash
# Install bastion-{ssh,sql,login} on Ubuntu.
#   - apt: openssh-client, proxychains4 (optional), xclip, ca-certificates, curl, gnupg, lsb-release
#   - azure-cli from Microsoft repo
#   - az extensions: ssh, bastion
#   - copies scripts + lib to ~/.local/bin
#   - drops config skeleton at ~/.config/bastion/config (if missing)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/bastion"

echo "[1/5] apt deps"
sudo apt-get update
sudo apt-get install -y \
  openssh-client ca-certificates curl gnupg lsb-release \
  proxychains4 xclip

echo "[2/5] azure-cli (Microsoft apt repo)"
if ! command -v az >/dev/null 2>&1; then
  sudo mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
  AZ_DIST="$(lsb_release -cs)"
  echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources >/dev/null
  sudo apt-get update
  sudo apt-get install -y azure-cli
fi

echo "[3/5] az extensions: ssh, bastion"
az extension add --name ssh --upgrade --only-show-errors || true
az extension add --name bastion --upgrade --only-show-errors || true

echo "[4/5] install scripts -> ${BIN_DIR}"
mkdir -p "$BIN_DIR"
install -m 0755 "$SCRIPT_DIR/bastion-ssh"   "$BIN_DIR/bastion-ssh"
install -m 0755 "$SCRIPT_DIR/bastion-sql"   "$BIN_DIR/bastion-sql"
install -m 0755 "$SCRIPT_DIR/bastion-login" "$BIN_DIR/bastion-login"
install -m 0644 "$SCRIPT_DIR/lib-common.sh" "$BIN_DIR/lib-common.sh"

echo "[5/5] config skeleton -> ${CONFIG_DIR}/config"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config" ]]; then
  install -m 0600 "$SCRIPT_DIR/config.example" "$CONFIG_DIR/config"
  echo "  Created $CONFIG_DIR/config — edit it before first use."
else
  echo "  Already exists; not overwriting. Compare with config.example for new keys."
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo
     echo "NOTE: $BIN_DIR not on PATH. Add to ~/.bashrc:"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo
echo "Done. Next:"
echo "  1. Edit $CONFIG_DIR/config (chmod 600)."
echo "  2. az login   (or bastion-login if behind Conditional Access)."
echo "  3. bastion-ssh dev   /   bastion-sql dev"
