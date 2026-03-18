{ pkgs, config, lib, ... }:

{
  imports = [
    ./portainer.nix
    ./mcphub.nix
  ];
  # ── quadlet-nix: Declarative Portainer container ──
  virtualisation.quadlet = {
    # ── Declare the named volume ──
    volumes = {
      portainer_data = {
        volumeConfig = { };
      };
    };

    networks = {
      portainer-net = {
        networkConfig = {
          subnets = [ "10.89.1.0/24" ];
        };
      };
    };
  };

}
