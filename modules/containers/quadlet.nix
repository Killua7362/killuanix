{ pkgs, config, lib, ... }:

{
  imports = [
    ./portainer.nix
    ./mcphub.nix
    ./officevm.nix
  ];
  # ── Enable podman user socket (rootless) ──
  systemd.user.services.podman-socket = {
    Unit.Description = "Podman API Socket (rootless)";
    Service = {
      ExecStart = "/usr/bin/podman system service --time=0 unix:///run/user/1000/podman/podman.sock";
      Type = "simple";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── quadlet-nix: Declarative Portainer container ──
  virtualisation.quadlet = {
    # ── Declare the named volume ──
    volumes = {
      portainer_data = {
        volumeConfig = {
        };
      };
    };

    networks = {
      portainer-net = {
        networkConfig = {
          subnets =[ "10.89.1.0/24"];
        };
      };
    };
  };

xdg.configFile."systemd/user/podman-user-wait-network-online.service.d/10-fix-path.conf" = {
  text = ''
    [Service]
    Environment=PATH=/usr/bin:/usr/sbin:/bin:/sbin
  '';
};

}
