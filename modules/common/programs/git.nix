{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
    userConfig = inputs.self.commonModules.user.userConfig;
in
{
    # Git configuration
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = userConfig.fullName;
          email = userConfig.email;
        };
      };
    };
}

