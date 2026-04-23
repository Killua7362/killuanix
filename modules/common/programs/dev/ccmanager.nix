# `ccmanager` — TUI for juggling multiple Claude Code sessions across git
# worktrees. Upstream (kbwo/ccmanager) is npm-only; we use the same
# lazy `npx --yes` pattern as `ruflo-cli.nix` — no eval-time npm closure,
# first run caches under $XDG_CACHE_HOME/ccmanager/.
#
# The Nix module owns:
#   - the `ccmanager` binary shim and `ccm` (= `ccmanager --multi-project`)
#   - two worktree-hook binaries that the declarative config references
#     by stable name (pre-creation dedupe + post-creation copy-staged)
#   - the full `~/.config/ccmanager/config.json` (read-only; TUI edits
#     under "Global Configuration" will not persist — edit this file and
#     `home-manager switch`)
#   - the `~/ccmanager-projects/` symlink farm used by `--multi-project`,
#     driven by the `ccmanagerProjects` attrset below
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Map of ccmanager project name → absolute path. Symlinks are created
  # blindly (no `.git` probing) so bare-repo worktree layouts work — see
  # ~/Documents/Boeing/azure/backend. Project names must be identifier-safe
  # (they become filenames under ~/ccmanager-projects/).
  ccmanagerProjects = {
    killuanix = "${config.home.homeDirectory}/killuanix";
    boeing = "${config.home.homeDirectory}/Documents/Boeing/azure/backend";
  };

  ccmanagerVersion = "latest";

  ccmanager = pkgs.writeShellApplication {
    name = "ccmanager";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ccmanager/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/ccmanager/npm-prefix"
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "ccmanager@${ccmanagerVersion}" "$@"
    '';
  };

  # `ccm` already taken by claude-monitor — use `ccmgr`.
  ccmgr = pkgs.writeShellApplication {
    name = "ccmgr";
    runtimeInputs = [ccmanager];
    text = ''exec ccmanager --multi-project "$@"'';
  };

  preCreationDedupe = pkgs.writeShellApplication {
    name = "ccmanager-pre-creation-dedupe";
    runtimeInputs = [pkgs.git pkgs.gawk];
    text = ''
      : "''${CCMANAGER_GIT_ROOT:?missing CCMANAGER_GIT_ROOT}"
      : "''${CCMANAGER_WORKTREE_BRANCH:?missing CCMANAGER_WORKTREE_BRANCH}"
      : "''${CCMANAGER_WORKTREE_PATH:?missing CCMANAGER_WORKTREE_PATH}"

      if git -C "$CCMANAGER_GIT_ROOT" worktree list --porcelain |
         awk -v b="refs/heads/$CCMANAGER_WORKTREE_BRANCH" \
           '$1=="branch" && $2==b {found=1} END {exit !found}'; then
        printf 'ccmanager: worktree for branch %s already exists — aborting\n' \
          "$CCMANAGER_WORKTREE_BRANCH" >&2
        exit 1
      fi

      if [ -e "$CCMANAGER_WORKTREE_PATH" ]; then
        printf 'ccmanager: path %s already exists — aborting\n' \
          "$CCMANAGER_WORKTREE_PATH" >&2
        exit 1
      fi
    '';
  };

  postCreationCopyStaged = pkgs.writeShellApplication {
    name = "ccmanager-post-creation-copy-staged";
    runtimeInputs = [pkgs.git pkgs.rsync];
    text = ''
      : "''${CCMANAGER_GIT_ROOT:?missing CCMANAGER_GIT_ROOT}"
      : "''${CCMANAGER_WORKTREE_PATH:?missing CCMANAGER_WORKTREE_PATH}"

      # Copy files the user has `git add`'d in the source repo but not yet
      # committed — i.e. the "Changes to be committed" set — into the new
      # worktree so work in progress carries over. Staged files inherently
      # respect .gitignore (ignored files can't be staged without -f), so no
      # extra filtering is needed. --diff-filter=ACMR excludes Deletions so
      # we don't try to copy paths that no longer exist. .git is excluded
      # defensively.
      git -C "$CCMANAGER_GIT_ROOT" diff --cached --name-only --diff-filter=ACMR -z |
        rsync -a --from0 --files-from=- --exclude='.git' \
          "$CCMANAGER_GIT_ROOT/" "$CCMANAGER_WORKTREE_PATH/"
    '';
  };

  cfg =
    {
      autoApproval.enabled = false;

      command = {
        command = "claude";
        args = [];
        fallbackArgs = [];
      };

      worktree = {
        autoDirectory = true;
        autoDirectoryPattern = "../{project}-worktrees/{branch}";
      };

      worktreeHooks = {
        pre_creation = {
          enabled = true;
          command = "ccmanager-pre-creation-dedupe";
        };
        post_creation = {
          enabled = true;
          command = "ccmanager-post-creation-copy-staged";
        };
      };
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      statusHooks = {
        idle = {
          enabled = true;
          command = ''notify-send 'ccmanager' "Session idle: $CCMANAGER_WORKTREE_BRANCH"'';
        };
        waiting_input = {
          enabled = true;
          command = ''notify-send -u critical 'ccmanager' "Waiting for input: $CCMANAGER_WORKTREE_BRANCH"'';
        };
        busy = {
          enabled = false;
          command = "";
        };
      };
    };
in {
  home.packages = [
    ccmanager
    ccmgr
    preCreationDedupe
    postCreationCopyStaged
  ];

  home.sessionVariables.CCMANAGER_MULTI_PROJECT_ROOT = "${config.home.homeDirectory}/ccmanager-projects";

  xdg.configFile."ccmanager/config.json".text = builtins.toJSON cfg;

  home.activation.ccmanagerProjects = lib.hm.dag.entryAfter ["writeBoundary"] ''
    root="$HOME/ccmanager-projects"
    mkdir -p "$root"
    # Only delete symlinks — leave any real files/dirs the user dropped in.
    find "$root" -mindepth 1 -maxdepth 1 -type l -delete
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
        name: path: ''
          ln -sfn ${lib.escapeShellArg path} "$root/${name}"''
      )
      ccmanagerProjects)}
  '';
}
