{
  pkgs,
  lib,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";
  # ── Container registry config ──
  environment.etc = {
    "containers/policy.json" = {
      text = builtins.toJSON {
        default = [{type = "insecureAcceptAnything";}];
      };
    };

    "containers/registries.conf" = {
      text = ''
        unqualified-search-registries = ["docker.io", "quay.io"]

        [[registry]]
        prefix = "docker.io"
        location = "docker.io"
      '';
    };

    "containers/storage.conf" = {
      text = ''
        [storage]
        driver = "overlay"

        [storage.options.overlay]
        mount_program = "/usr/bin/fuse-overlayfs"
      '';
    };

    "subuid" = {
      text = "killua:100000:65536\n";
    };

    "subgid" = {
      text = "killua:100000:65536\n";
    };
  };

  # ── Enable lingering for rootless (services start at boot) ──
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/killua 0644 root root -"
  ];

  # ── Podman socket (rootful, system-level) ──
  # systemd.services."podman-socket" = {
  #   description = "Podman API Socket (system)";
  #   wantedBy = [ "sockets.target" ];
  #   serviceConfig = {
  #     ExecStart = "/usr/bin/podman system service --time=0 unix:///run/podman/podman.sock";
  #     Type = "simple";
  #   };
  # };
}
