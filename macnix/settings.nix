{
  config,
  lib,
  pkgs,
  ...
}: {
  # Nix configuration ------------------------------------------------------------------------------

  programs.zsh.enable = true;

  nix.settings.substituters = [
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
  nix.settings.trusted-users = [
    "@admin"
  ];
  nix.configureBuildUsers = true;

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions =
    ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    ''
    + lib.optionalString (pkgs.system == "aarch64-darwin") ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';

  # Auto upgrade nix package and the daemon service.

  services.nix-daemon.enable = true;
  security.pam.enableSudoTouchIdAuth = true;

  # Shells -----------------------------------------------------------------------------------------

  # Add shells installed by nix to /etc/shells file
  environment.shells = with pkgs; [
    zsh
  ];

  # Make zsh the default shell
  programs.nix-index.enable = true;
  programs.zsh.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
  '';
  # Needed to address bug where $PATH is not properly set for fish:
  # https://github.com/LnL7/nix-darwin/issues/122

  environment.variables.SHELL = "${pkgs.zsh}/bin/zsh";

  system.keyboard = {
    enableKeyMapping = true;
    swapLeftCommandAndLeftAlt = true;
  };
  system.defaults = {
    NSGlobalDomain.NSAutomaticWindowAnimationsEnabled = true;
    dock = {
      expose-animation-duration = 0.0;
    };
    alf = {
      globalstate = 1;
      allowsignedenabled = 1;
      allowdownloadsignedenabled = 1;
      stealthenabled = 1;
    };
    NSGlobalDomain = {
      /*
       NSWindowResizeTime = "0.001";
      NSScrollAnimationEnabled = false;
      */
      AppleKeyboardUIMode = 3;
      /*
      _HIHideMenuBar = false;
      */
      /*
       InitialKeyRepeat = 15;
      KeyRepeat = 2;
      */
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  #system.stateVersion = 4;
}
