{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  userConfig = inputs.self.commonModules.user.userConfig;
  azureGitConfigPath = "${config.home.homeDirectory}/.config/git/config-azure";
  dasGitConfigPath = "${config.home.homeDirectory}/.config/git/config-das";
in {
  sops.templates."config-azure" = {
    content = ''
      [user]
          name = ${config.sops.placeholder."boeing/git_name"}
          email = ${config.sops.placeholder."boeing/git_email"}
    '';
    path = azureGitConfigPath;
  };

  sops.templates."config-das" = {
    content = ''
      [user]
          name = ${config.sops.placeholder."das/git_name"}
          email = ${config.sops.placeholder."das/git_email"}
    '';
    path = dasGitConfigPath;
  };

  programs.git = {
    enable = true;

    # Global gitignore — written by HM to ~/.config/git/ignore and pointed to
    # by core.excludesFile. Single source of truth across every host/repo.
    ignores = [
      ".gitnexus/" # GitNexus per-repo knowledge graph (rebuildable, never commit)
      # `den` host-side state. Lives next to bound working dirs; per-host only.
      ".den-meta.json"
      ".den-meta.json.lock"
      ".den-meta.json.reflog"
      ".den-staging/"
      ".den-generations/"
    ];

    settings = {
      user = {
        name = userConfig.fullName;
        email = userConfig.email;
      };
      "http \"https://dev.azure.com\"" = {
        proxy = "socks5h://127.0.0.1:1080";
      };
      "http \"https://gitlab-ext.digitalaviationservices.com\"" = {
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
        condition = "hasconfig:remote.*.url:https://gitlab-ext.digitalaviationservices.com/**";
        path = dasGitConfigPath;
      }
      {
        condition = "hasconfig:remote.*.url:https://*@gitlab-ext.digitalaviationservices.com/**";
        path = dasGitConfigPath;
      }
      {
        condition = "hasconfig:remote.*.url:git@gitlab-ext.digitalaviationservices.com:**";
        path = dasGitConfigPath;
      }
    ];
  };

  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
        rv = "repo view --web";
      };
    };
  };
}
