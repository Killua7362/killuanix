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
    # Swap physical left-Cmd and left-Alt at the OS level. This is what
    # makes the AeroSpace `alt-…` bindings (services.nix) trigger from the
    # physical left-Cmd key — i.e. the Linux-style "Super on the left of
    # space" hand position. If you flip this off, also rewrite AeroSpace
    # bindings to `cmd-…`.
    swapLeftCommandAndLeftAlt = true;
  };

  system.defaults = {
    # Application Layer Firewall — block incoming, allow signed apps.
    alf = {
      globalstate = 1;
      allowsignedenabled = 1;
      allowdownloadsignedenabled = 1;
      stealthenabled = 1;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.4;
      expose-animation-duration = 0.0;
      show-recents = false;
      mineffect = "scale";
      minimize-to-application = true;
      magnification = false;
      tilesize = 48;
      persistent-apps = []; # populate later
      persistent-others = [];
      # Hot corners: 1 = no-op (disabled).
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = false;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXDefaultSearchScope = "SCcf"; # search current folder
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
      QuitMenuItem = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
      TrackpadRightClick = true;
    };

    screencapture = {
      location = "~/Desktop/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      AppleInterfaceStyle = "Dark";
      AppleShowScrollBars = "Always";
      NSAutomaticWindowAnimationsEnabled = true;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
      "com.apple.keyboard.fnState" = false;
      "com.apple.swipescrolldirection" = true;
      "com.apple.trackpad.scaling" = 1.5;
    };

    hitoolbox.AppleFnUsageType = "Do Nothing";
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  #system.stateVersion = 4;
}
