#!/bin/bash


if ! [ ! -x "$(command -v nix)" ]; then
  echo 'Nix is not installed start installing' >&2
  if [[ "$(uname)" == "Darwin" ]]; then
	sh <(curl -L https://nixos.org/nix/install) --darwin-use-unencrypted-nix-store-volume --daemon
	echo "source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" > ~/.bashrc
	if ! [ -x "$(command -v git)" ]; then
		echo "git is not installed."
	else
		git clone --recurse-submodules --remote-submodules https://github.com/Killua7362/killuanix.git
		cd killuanix
		nix --extra-experimental-features 'flakes nix-command' build .#darwinConfigurations.macnix.system
		./result/sw/bin/darwin-rebuild switch --flake .#macnix
	fi
  fi
  exit 1
fi
