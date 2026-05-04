# `den` — project-scoped symlink + patch manager.
#
# A small CLI that binds named projects (under Notes/projects/<NAME>/) to
# working directories via symlinks. Project state travels in the Notes git
# repo; per-host binding state lives in <cwd>/.den-meta.json (globally
# gitignored). See `den help` for the full command surface and the design
# doc at ~/.claude/plans/could-i-have-a-cheeky-stallman.md.
#
# Implementation: Bash dispatcher (./scripts/) + Python helper sidecar
# (./helper/, exposed as `den-helper`) for tree-walk, manifest hashing,
# JSONL ops, and 3-state diff. Both bodies are split into per-subcommand
# files so shell + python LSPs can navigate them. See ./CLAUDE.md.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.programs.den;

  # Python helper library — bundled by runCommand, then `writePython3Bin`
  # ships a tiny entry stub that adds it to sys.path and calls main().
  denHelperLib = pkgs.runCommand "den-helper-lib" {} ''
    mkdir -p $out
    cp -r ${./helper}/* $out/
  '';

  den-helper =
    pkgs.writers.writePython3Bin "den-helper" {
      flakeIgnore = ["E501" "E302" "E305" "E306" "W503" "E402" "E741"];
    } ''
      import sys
      sys.path.insert(0, "${denHelperLib}")
      from main import main
      main()
    '';

  # Bash CLI — sources lib/*.sh + cmd/*.sh from $DEN_LIB_DIR.
  denScripts = pkgs.runCommand "den-scripts" {} ''
    mkdir -p $out
    cp -r ${./scripts}/* $out/
  '';

  den = pkgs.writeShellApplication {
    name = "den";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnused
      gnugrep
      gawk
      diffutils
      jq
      fzf
      bat
      rsync
      git
      util-linux # flock
      getopt
      openssh
      den-helper
    ];
    excludeShellChecks = [
      "SC2088" # `~/foo` strings are display labels, not paths
      "SC2155" # local x="$(...)" — exit-code-loss intentional
      "SC2046" # word splitting in `for ... in $(...)` is intentional
      "SC2086" # double-quote elision intentional in some places
      "SC2034" # unused vars are stub-related
      "SC1007" # multi-var local declarations
      "SC2209" # echo to var indirectly
      "SC2012" # `ls -A` is acceptable for our directory checks
      "SC2128" # array-as-string in some _do_pull paths
      "SC2178" # array assignment to scalar (false positive)
      "SC2207" # mapfile not available everywhere
      "SC2206" # word splitting on assignment
      "SC2317" # unreachable command (we have shell stubs)
      "SC2016" # backticks inside single quotes are intentional doc strings
    ];
    text = ''
      export DEN_LIB_DIR=${denScripts}
      export DEN_HELPER_BIN=${den-helper}/bin/den-helper
      exec bash ${denScripts}/den.sh "$@"
    '';
  };
in {
  options.programs.den = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the den project switcher.";
    };
    notesPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/killuanix/Notes";
      description = "Path to the Notes git repo containing Notes/projects/.";
    };
    snapshotContent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, generations also write a tarball of files/ for force-push-proof rollback.";
    };
    zoxide = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, `den pull` opportunistically calls `zoxide add` when zoxide is on PATH.";
    };
    starshipBlock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, programs.starship.settings.custom.den is auto-configured.";
    };
    projects = lib.mkOption {
      default = {};
      description = "Per-project hooks and files declared in Nix.";
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          hooks = lib.mkOption {
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                scope = lib.mkOption {
                  type = lib.types.enum ["host" "shared"];
                  default = "host";
                };
                text = lib.mkOption {type = lib.types.lines;};
                executable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                };
              };
            });
          };
          files = lib.mkOption {
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                scope = lib.mkOption {
                  type = lib.types.enum ["host" "shared"];
                  default = "host";
                };
                source = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                };
                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                };
              };
            });
          };
        };
      }));
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) (let
    overlayDir = "${config.home.homeDirectory}/.local/share/den/overlay";

    # All host-scoped hooks/files across all projects, flattened.
    hostHookFiles = lib.concatLists (lib.mapAttrsToList (projName: proj:
      lib.mapAttrsToList (hookName: hook: {
        target = "${overlayDir}/${projName}/hooks/${hookName}";
        executable = hook.executable;
        text = hook.text;
      }) (lib.filterAttrs (_: v: v.scope == "host") proj.hooks))
    cfg.projects);

    hostContentFiles = lib.concatLists (lib.mapAttrsToList (projName: proj:
      lib.mapAttrsToList (path: file: {
        target = "${overlayDir}/${projName}/files/${path}";
        source = file.source;
        text = file.text;
      }) (lib.filterAttrs (_: v: v.scope == "host") proj.files))
    cfg.projects);

    # Shared scope writes into Notes via activation, with marker check.
    sharedEntries = lib.concatLists (lib.mapAttrsToList (projName: proj:
      (lib.mapAttrsToList (hookName: hook: {
        inherit projName;
        relPath = "hooks/${hookName}";
        executable = hook.executable;
        text = hook.text;
      }) (lib.filterAttrs (_: v: v.scope == "shared") proj.hooks))
      ++ (lib.mapAttrsToList (path: file: {
        inherit projName;
        relPath = "files/${path}";
        executable = false;
        text =
          if file.text != null
          then file.text
          else builtins.readFile file.source;
      }) (lib.filterAttrs (_: v: v.scope == "shared" && (v.text != null || v.source != null)) proj.files)))
    cfg.projects);
  in {
    home.packages = [den den-helper];

    home.sessionVariables = {
      DEN_NOTES = cfg.notesPath;
    };

    # Host-scoped overlay: standard home.file.
    home.file = lib.mkMerge [
      (lib.listToAttrs (map (e: {
          name = lib.removePrefix "${config.home.homeDirectory}/" e.target;
          value = {
            text = e.text;
            executable = e.executable;
          };
        })
        hostHookFiles))
      (lib.listToAttrs (map (e: {
          name = lib.removePrefix "${config.home.homeDirectory}/" e.target;
          value =
            if e.source != null
            then {source = e.source;}
            else {text = e.text;};
        })
        hostContentFiles))
    ];

    # Shared-scope writer: refuse to clobber files the user has edited.
    home.activation.den-shared = lib.hm.dag.entryAfter ["writeBoundary"] ''
      DEN_MARKER='# den-managed (do not edit)'
      ${lib.concatMapStringsSep "\n" (e: ''
                  target="${cfg.notesPath}/projects/${e.projName}/${e.relPath}"
                  mkdir -p "$(dirname "$target")"
                  if [ -f "$target" ] && ! head -n1 "$target" | grep -qF "$DEN_MARKER"; then
                    echo "den: refusing to overwrite user-edited $target" >&2
                  else
                    tmp="$(mktemp)"
                    {
                      echo "$DEN_MARKER"
                      cat <<'DEN_EOF'
          ${e.text}
          DEN_EOF
                    } > "$tmp"
                    mv "$tmp" "$target"
                    ${lib.optionalString e.executable ''chmod +x "$target"''}
                  fi
        '')
        sharedEntries}
    '';

    # Completions auto-installed.
    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
      # den completion
      if command -v den >/dev/null; then
        fpath+=("${config.xdg.dataHome}/zsh/site-functions")
        eval "$(den completion zsh 2>/dev/null || true)"
      fi
    '';

    programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
      command -v den >/dev/null && eval "$(den completion bash 2>/dev/null || true)"
    '';

    # Starship prompt block — opt-out via cfg.starshipBlock = false.
    programs.starship.settings = lib.mkIf (cfg.starshipBlock && config.programs.starship.enable) {
      custom.den = {
        command = "den prompt";
        when = "test -f .den-meta.json";
        format = "[$output]($style) ";
        style = "bold cyan";
      };
    };
  });
}
