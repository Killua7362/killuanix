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

  # Read-only credential helper for Claude's sandbox. Answers `get` with a
  # read-only PAT from sops; ignores `store`/`erase` so git never persists it.
  roHelper = name: user: secret:
    pkgs.writeShellScript "git-credential-ro-${name}" ''
      cat >/dev/null
      [ "$1" = get ] || exit 0
      tok=$(cat ${config.sops.secrets.${secret}.path} 2>/dev/null) || exit 0
      [ -n "$tok" ] || exit 0
      printf 'username=%s\npassword=%s\n' ${user} "$tok"
    '';

  # Injected via GIT_CONFIG_{COUNT,KEY_n,VALUE_n} env vars (highest config
  # precedence). The empty helper first resets any helper list inherited
  # from config files, so inside the sandbox only the RO token is ever used.
  claudeGitConfig = [
    ["credential.https://dev.azure.com.helper" ""]
    ["credential.https://dev.azure.com.helper" "${roHelper "azure" "pat" "boeing/azure_token"}"]
    ["credential.https://gitlab-ext.digitalaviationservices.com.helper" ""]
    ["credential.https://gitlab-ext.digitalaviationservices.com.helper" "${roHelper "gitlab" "oauth2" "boeing/gitlab_token"}"]
  ];
in {
  # Claude-only read-only git credentials: set inside Claude's bwrap sandbox
  # (overlayClaude --setenv), never in the user's shell. Pushes from Claude
  # fail server-side (RO token); the user's terminal never sees the RO token,
  # so manual pushes prompt for the write token.
  # GIT_ASKPASS=false + no terminal prompt: if a RO helper fails, git must
  # error out rather than fall back to SSH_ASKPASS (ksshaskpass), which
  # would hand claude the user's KWallet-saved write token.
  local.claudeExtraEnv =
    {
      GIT_ASKPASS = "${pkgs.coreutils}/bin/false";
      GIT_TERMINAL_PROMPT = "0";
      GIT_CONFIG_COUNT = toString (builtins.length claudeGitConfig);
    }
    // lib.listToAttrs (lib.concatLists (lib.imap0 (i: kv: [
        (lib.nameValuePair "GIT_CONFIG_KEY_${toString i}" (builtins.elemAt kv 0))
        (lib.nameValuePair "GIT_CONFIG_VALUE_${toString i}" (builtins.elemAt kv 1))
      ])
      claudeGitConfig));

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
      # `den` host-side state. Lives next to bound working dirs; per-host only.
      # All state now consolidated into a single `.den/` dir (git-style); the
      # legacy flat `.den-*` entries are kept so un-migrated dirs stay ignored.
      ".den/"
      ".den-staging/"
      ".den-meta.json"
      ".den-meta.json.lock"
      ".den-meta.json.reflog"
      ".den-generations/"
    ];

    settings = {
      user = {
        name = userConfig.fullName;
        email = userConfig.email;
      };
      core = {
        # -F: quit if output fits one screen (no pager for short diffs).
        # -X: don't clear screen on exit, so output stays in terminal.
        pager = "less -FX";
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
