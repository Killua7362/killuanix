# Common modules that can be used across different configurations
{
  packages = import ./packages.nix;
  user = import ./user.nix;
  overlays = import ./overlays.nix;
  overrides = import ./overrides.nix;
  programs = import ./programs.nix;
}
