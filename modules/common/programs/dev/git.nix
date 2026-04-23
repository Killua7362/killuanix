{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  userConfig = inputs.self.commonModules.user.userConfig;
  azureGitConfigPath = "${config.home.homeDirectory}/.config/git/config-azure";
in {
  sops.templates."config-azure" = {
    content = ''
      [user]
          name = ${config.sops.placeholder."boeing/git_name"}
          email = ${config.sops.placeholder."boeing/git_email"}
    '';
    path = azureGitConfigPath;
  };

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = userConfig.fullName;
        email = userConfig.email;
      };
      "http \"https://dev.azure.com\"" = {
        proxy = "socks5h://127.0.0.1:1080";
      };
      extensions = {
        worktreeConfig = true;
      };
    };

    includes = [
      {
        condition = "hasconfig:remote.*.url:https://*@dev.azure.com/**";
        path = azureGitConfigPath;
      }
      {
        condition = "hasconfig:remote.*.url:https://*@dev.azure.com/**";
        path = azureGitConfigPath;
      }
    ];
  };
}
