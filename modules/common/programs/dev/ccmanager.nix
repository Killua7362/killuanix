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
#   - the `~/ccmanager-projects/` farm used by `--multi-project`, built
#     as bindfs user mounts on Linux (ccmanager skips symlinks — its
#     scanner uses `Dirent.isDirectory()` which returns false for
#     symbolic links) and as symlinks on macOS where bindfs isn't
#     wired up. Driven by the `ccmanagerProjects` attrset below.
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Map of ccmanager project name → absolute path. Each entry is exposed
  # under ~/ccmanager-projects/<name> as a bindfs FUSE mount (Linux) so
  # ccmanager's `Dirent.isDirectory()` scan picks it up. Project paths
  # must point at a real git clone (`.git/` as a directory) — bare-repo
  # + worktree layouts are excluded by ccmanager's `isMainGitRepository()`
  # check. Names must be identifier-safe (they become filenames under
  # the mount root).
  ccmanagerProjects = {
    killuanix = "${config.home.homeDirectory}/killuanix";
    boeing = "${config.home.homeDirectory}/Documents/Boeing/azure/backend";
  };

  mountRoot = "${config.home.homeDirectory}/ccmanager-projects";

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
  # Self-sufficient: sets CCMANAGER_MULTI_PROJECT_ROOT if the session-var
  # wasn't sourced (e.g. shell predates last home-manager switch).
  ccmgr = pkgs.writeShellApplication {
    name = "ccmgr";
    runtimeInputs = [ccmanager];
    text = ''
      export CCMANAGER_MULTI_PROJECT_ROOT="''${CCMANAGER_MULTI_PROJECT_ROOT:-${mountRoot}}"
      exec ccmanager --multi-project "$@"
    '';
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

  cfg = {
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
  };
in {
  home.packages =
    [
      ccmanager
      ccmgr
      preCreationDedupe
      postCreationCopyStaged
    ]
    ++ lib.optional pkgs.stdenv.isLinux pkgs.bindfs;

  home.sessionVariables.CCMANAGER_MULTI_PROJECT_ROOT = mountRoot;

  xdg.configFile."ccmanager/config.json".text = builtins.toJSON cfg;

  # Prepare the mount root and per-project mountpoints. Legacy symlinks
  # from the previous layout are cleaned up; real directories (bindfs
  # mountpoints or anything the user has dropped in) are preserved.
  home.activation.ccmanagerProjects = lib.hm.dag.entryAfter ["writeBoundary"] ''
    root=${lib.escapeShellArg mountRoot}
    mkdir -p "$root"
    find "$root" -mindepth 1 -maxdepth 1 -type l -delete
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
        name: _: ''
          mkdir -p "$root/${name}"''
      )
      ccmanagerProjects)}
    ${lib.optionalString (!pkgs.stdenv.isLinux) (
      # On non-Linux (macOS) fall back to symlinks — bindfs services
      # aren't wired there. Kept so ccmanagerProjects still resolves.
      lib.concatStringsSep "\n" (lib.mapAttrsToList (
          name: path: ''
            ln -sfn ${lib.escapeShellArg path} "$root/${name}"''
        )
        ccmanagerProjects)
    )}
  '';

  # One bindfs user service per project. Each performs a FUSE bind of
  # the real repo onto ~/ccmanager-projects/<name>. `Type=simple` with
  # `bindfs -f` means SIGTERM triggers a clean unmount on stop, and
  # the stale-mount ExecStartPre (prefixed `-`) covers the case where a
  # previous run exited without unmounting.
  systemd.user.services = lib.optionalAttrs pkgs.stdenv.isLinux (
    lib.mapAttrs' (
      name: path:
        lib.nameValuePair "ccmanager-bindfs-${name}" {
          Unit = {
            Description = "bindfs mount for ccmanager project '${name}' (${path})";
            After = ["default.target"];
          };
          Service = {
            Type = "simple";
            ExecStartPre = [
              "${pkgs.coreutils}/bin/mkdir -p ${mountRoot}/${name}"
              "-${pkgs.fuse3}/bin/fusermount3 -u ${mountRoot}/${name}"
            ];
            # --no-allow-other: single-user mount; avoids the
            # `/etc/fuse.conf` + `user_allow_other` requirement.
            ExecStart = "${pkgs.bindfs}/bin/bindfs -f --no-allow-other ${path} ${mountRoot}/${name}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = ["default.target"];
        }
    )
    ccmanagerProjects
  );
}
