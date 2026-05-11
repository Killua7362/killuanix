#!/usr/bin/env bash
# Convert an OpenSSH ed25519 private key into an age key and save it to
# ~/.config/sops/age/keys.txt (or $SOPS_AGE_KEY_FILE if set).
#
# Self-bootstraps `ssh-to-age` via `nix shell nixpkgs#ssh-to-age` if
# the binary is not on PATH — works on a fresh NixOS box with only nix.
#
# Usage:
#   ./convert-ssh-to-age.sh /path/to/ssh/private/key
#   ./convert-ssh-to-age.sh -          # read key from stdin
#
# Env:
#   SOPS_AGE_KEY_FILE   override output path (use a /tmp path to test)
#   FORCE=1             allow overwriting an existing non-empty key file
#                       (still prompts interactively before replacing)
#
# Safety:
# - Refuses to overwrite a non-empty existing target without FORCE=1.
# - Even with FORCE=1, prints existing public-key fingerprint and asks Y/n.
# - Tmp files are mode 600 and removed on exit.

set -euo pipefail

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage; exit 0
fi
if [[ $# -lt 1 ]]; then
  usage; exit 2
fi

KEY_ARG="$1"
TARGET="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

# --- self-bootstrap ssh-to-age via nix shell -------------------------
if ! command -v ssh-to-age >/dev/null 2>&1; then
  if ! command -v nix >/dev/null 2>&1; then
    echo "[x] neither ssh-to-age nor nix are available on PATH" >&2
    exit 1
  fi
  echo "[*] ssh-to-age missing — re-exec under nix shell nixpkgs#ssh-to-age"
  exec nix shell --extra-experimental-features 'nix-command flakes' \
    nixpkgs#ssh-to-age --command "$0" "$@"
fi

# --- read input key into a tmp file (mode 600) -----------------------
tmp="$(mktemp)"
out_tmp="$(mktemp)"
trap 'rm -f "$tmp" "$out_tmp"' EXIT
chmod 600 "$tmp" "$out_tmp"

if [[ "$KEY_ARG" == "-" ]]; then
  echo "[*] reading ssh private key from stdin"
  cat > "$tmp"
else
  if [[ ! -r "$KEY_ARG" ]]; then
    echo "[x] cannot read $KEY_ARG" >&2
    exit 1
  fi
  cat "$KEY_ARG" > "$tmp"
fi

if [[ ! -s "$tmp" ]]; then
  echo "[x] key input is empty" >&2
  exit 1
fi

if ! head -n1 "$tmp" | grep -q 'OPENSSH PRIVATE KEY'; then
  echo "[!] input does not look like an OpenSSH private key (no PEM header)" >&2
  echo "    proceeding — ssh-to-age will fail loud if it isn't" >&2
fi

# --- target safety ---------------------------------------------------
target_dir="$(dirname "$TARGET")"
mkdir -p "$target_dir"
# Only tighten perms on dirs we own (skip /tmp etc.).
if [[ -O "$target_dir" ]]; then
  chmod 700 "$target_dir"
fi

if [[ -s "$TARGET" ]]; then
  echo "[!] $TARGET exists and is non-empty" >&2
  existing_pub="$(grep -m1 '^# public key:' "$TARGET" 2>/dev/null || true)"
  [[ -n "$existing_pub" ]] && echo "    existing $existing_pub" >&2
  if [[ "${FORCE:-0}" != "1" ]]; then
    echo "    refusing to overwrite — re-run with FORCE=1 to replace" >&2
    exit 1
  fi
  read -r -p "OVERWRITE existing key at $TARGET? [y/N] " yn
  [[ "$yn" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# --- convert ---------------------------------------------------------
ssh-to-age -private-key -i "$tmp" -o "$out_tmp"

if ! grep -q '^AGE-SECRET-KEY-' "$out_tmp"; then
  echo "[x] ssh-to-age output does not look like an age key" >&2
  exit 1
fi

# Derive the matching age recipient from the public half so the file
# carries a '# public key: age1...' comment (sops-nix tooling and
# 00-age-key verification both look for this).
age_pub=""
if command -v ssh-keygen >/dev/null 2>&1; then
  if pub="$(ssh-keygen -y -f "$tmp" 2>/dev/null)"; then
    age_pub="$(printf '%s\n' "$pub" | ssh-to-age 2>/dev/null || true)"
  fi
fi

final_tmp="$(mktemp)"
chmod 600 "$final_tmp"
if [[ -n "$age_pub" ]]; then
  printf '# created: %s\n# public key: %s\n' "$(date -Iseconds)" "$age_pub" > "$final_tmp"
fi
cat "$out_tmp" >> "$final_tmp"
install -m 600 "$final_tmp" "$TARGET"
rm -f "$final_tmp"

echo "[ok] wrote $TARGET"
grep -m1 '^# public key:' "$TARGET" || echo "[!] no '# public key:' comment in output"

cat <<EOF

next:
  nix run --extra-experimental-features 'nix-command flakes' \\
    nixpkgs#sops -- -d secrets/personal.yaml >/dev/null && echo OK
EOF
