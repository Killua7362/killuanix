{
  pkgs,
  config,
  inputs,
  nixgl,
  libs,
  ...
}: {
  imports = [
    ../modules/cross-platform
    ./users/dots-manage.nix
    ./users/commands.nix
    ./users/appimages.nix
  ];

  # AppImages configuration (Linux specific)
  myAppImages = {
    enable = true;

    apps = {
      "PrismLauncher" = {
        repoOwner = "Diegiwg";
        repoName = "PrismLauncher-Cracked";
        releaseTag = "9.4";
        fileName = "PrismLauncher-Linux-x86_64.AppImage";
      };
      "Anymex" = {
        repoOwner = "RyanYuuki";
        repoName = "AnymeX";
        releaseTag = "v3.0.1";
        fileName = "AnymeX-Linux.AppImage";
      };
    };
  };

  # Linux-specific state version
  home.stateVersion = "24.11";
}
