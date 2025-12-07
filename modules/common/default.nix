# Common modules that can be used across different configurations
{
  packages = import ./packages.nix;
  user = import ./user.nix;
}