{ pkgs, config, ... }:

{
  services.picom = {
    enable = true;
    package = pkgs.nur.repos.reedrw.picom-next-ibhagwan;
    blur = true;
        extraOptions = ''
          corner-radius = 10;
          blur-method = "dual_kawase";
          blur-strength = "10";
          xinerama-shadow-crop = true;
        '';
        experimentalBackends = true;
    vSync = false;
#     activeOpacity = "0.95";
#     inactiveOpacity = "0.95"; 
    backend = "xrender";
    fade = true;
    fadeDelta = 5;
    shadow = true;
    shadowOpacity = "0.9";
    opacityRule = [ "100:class_g = 'Nightly' " ];
  };
}

