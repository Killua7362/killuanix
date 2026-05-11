#!/usr/bin/env bash
# killuanix bootstrap — clone the public repo (no submodules) on a fresh box.
#
# Designed to be piped from curl on a newly-installed NixOS system that
# has only git, curl, and bash:
#
#   curl -fsSL https://raw.githubusercontent.com/Killua7362/killuanix/master/post-install/bootstrap.sh | bash
#
# Override destination with KILLUANIX_DIR:
#
#   curl -fsSL <url> | KILLUANIX_DIR=$HOME/work/killuanix bash
#
# Submodules (Notes, DotFiles, aconfmgr) are private and need a GitHub
# token, so they are intentionally skipped.

set -euo pipefail

REPO="https://github.com/Killua7362/killuanix.git"
DEST="${KILLUANIX_DIR:-$HOME/killuanix}"

if [[ -e "$DEST" ]]; then
  echo "[!] $DEST already exists — refusing to clobber" >&2
  echo "    set KILLUANIX_DIR=<path> or remove $DEST first" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[x] git not found on PATH" >&2
  exit 1
fi

echo "[*] cloning $REPO -> $DEST (no submodules)"
git clone --no-recurse-submodules "$REPO" "$DEST"

cat <<EOF

[ok] repo at $DEST

Day 0 quickstart (run inside $DEST):

  # 1. Replace the host's hardware config with the freshly generated one
  HOST=\$(hostname -s)              # chrollo or killua
  cp /etc/nixos/hardware-configuration.nix "\$HOST/hardware-configuration.nix"

  # 2. Convert your Bitwarden ssh-ed25519 private key into an age key.
  #    Save the key to a tmp file first (paste from Bitwarden), then:
  ./post-install/convert-ssh-to-age.sh /tmp/sshkey
  shred -u /tmp/sshkey 2>/dev/null || rm -f /tmp/sshkey

  # 3. Verify sops can decrypt with the new age key (read-only)
  nix run --extra-experimental-features 'nix-command flakes' \\
    nixpkgs#sops -- -d secrets/personal.yaml >/dev/null && echo OK

  # 4. First system build (replace <hostname> with chrollo or killua)
  sudo nixos-rebuild switch --flake .#\$HOST

  # 5. First home-manager build (no home-manager CLI on PATH yet)
  nix run --extra-experimental-features 'nix-command flakes' \\
    home-manager/master -- switch --flake .#\$HOST

  # 6. Walk the rest of the runbook
  cat post-install/INSTRUCTIONS.md
  ./post-install/run.sh list
EOF
