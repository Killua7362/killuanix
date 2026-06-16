#!/usr/bin/env bash
# oracle-vm-import.sh — one-shot import of the Oracle 19c vagrant OVA into
# ~/VMs/oracle-19c.qcow2 for the libvirt domain defined in
# modules/vms/oracle-19c-vm.nix.
#
# Why: nix activation only declares the libvirt domain — it intentionally does
# not extract the 17 GB OVA / qemu-img convert it on every home-manager switch.
# Run this once after the first switch; the domain points at
# $HOME/VMs/oracle-19c.qcow2.
#
# Usage:
#   scripts/oracle-vm-import.sh                # auto-pick newest OVA in ~/Downloads
#   scripts/oracle-vm-import.sh path/to.ova    # explicit OVA
#   scripts/oracle-vm-import.sh --force [ova]  # overwrite an existing qcow2

set -euo pipefail

force=0
ova=""
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ova="$arg" ;;
  esac
done

out="$HOME/VMs/oracle-19c.qcow2"
mkdir -p "$HOME/VMs"

if [ -f "$out" ] && [ "$force" -ne 1 ]; then
  echo "refusing to overwrite $out (pass --force to replace)" >&2
  exit 1
fi

if [ -z "$ova" ]; then
  # Newest *.ova in ~/Downloads matching oracle-19c
  ova="$(find "$HOME/Downloads" -maxdepth 1 -type f -iname 'oracle-19c*.ova' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | head -n1 | cut -d' ' -f2-)"
fi

if [ -z "$ova" ] || [ ! -f "$ova" ]; then
  echo "no OVA found — expected oracle-19c*.ova in ~/Downloads, or pass a path" >&2
  exit 1
fi

for cmd in tar qemu-img; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not found in PATH" >&2
    exit 1
  fi
done

echo "OVA:    $ova"
echo "Target: $out"

workdir="$(mktemp -d -t oracle-19c-ova.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

echo "Extracting OVA …"
tar -xf "$ova" -C "$workdir"

vmdk="$(find "$workdir" -maxdepth 2 -type f \( -iname '*.vmdk' -o -iname '*.vdi' -o -iname '*.qcow2' \) | head -n1)"
if [ -z "$vmdk" ]; then
  echo "no disk image found inside OVA" >&2
  exit 1
fi
echo "Disk:   $vmdk"

echo "Converting → qcow2 (this can take a few minutes for a 30–50 GB output) …"
qemu-img convert -p -O qcow2 -o compat=1.1 "$vmdk" "$out.tmp"
mv -f "$out.tmp" "$out"

echo "Done."
qemu-img info "$out"

echo
echo "Next:"
echo "  virsh -c qemu:///system start oracle-19c"
echo "  virsh -c qemu:///system net-dhcp-leases default   # find guest IP"
