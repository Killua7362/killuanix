{ pkgs, lib, ... }: {
  nix = {
    extraOptions = ''
      system = aarch64-darwin
      extra-platforms = aarch64-darwin x86_64-darwin
      experimental-features = nix-command flakes
      build-users-group = nixbld
    '';
  };
  environment.systemPackages = with pkgs; [
    wget
    eza
    nixfmt-classic
    niv
  ];
}
