# `claude-powerline` — declarative Claude Code status line (replacement for
# ccstatusline). Cheaper at runtime: instead of paying Node + `npx` resolution
# on every refresh, we lazy-compile the upstream JS into a single Bun-native
# binary via `bun build --compile` and cache it under
# `$XDG_CACHE_HOME/claude-powerline/bin-v<version>/claude-powerline`. First run
# pays ~5-10s of `bun install` + compile; every subsequent render is one cold
# exec of a self-contained binary (~5-20ms).
#
# Pieces:
#   1. `claude-powerline` shim: checks cache; if the version-keyed compiled
#      binary exists, runs it; otherwise `bun add` the pinned package, runs
#      `bun build --compile`, then runs it. Version bumps land in a new cache
#      sub-dir so old binaries naturally get GC'd by manual
#      `rm -rf $XDG_CACHE_HOME/claude-powerline/`. After the binary runs, the
#      shim emits a single status row (bar segments + optional caveman
#      badge). Vertical spacing is left to Claude Code's own padding.
#   2. Declarative `~/.config/claude-powerline/config.json` rendered as a raw
#      JSON template string (NOT `builtins.toJSON` of an attrset). Reason:
#      claude-powerline renders segments in the JSON insertion order of
#      `display.lines[].segments`, but Nix's `builtins.toJSON` alphabetises
#      attrset keys on serialisation, which silently scrambles the layout.
#      Edit the `segmentOrder` list + the `configJson` template below, then
#      `scripts/nix_switch`.
#
# Wiring into Claude Code lives in `claude.nix` via
# `programs.claude-code.settings.statusLine.command = "claude-powerline"`
# (PATH lookup so launchers under `claude-launchers.nix` inherit it).
#
# Schema reference (Owloops/claude-powerline):
#   - top-level: theme, display{padding,style,charset,lines[]}, colors.custom
#   - segments per line: model, thinking, context, git, directory, block, …
#   - style options: minimal | powerline | capsule | tui. We use `minimal` —
#     closest to ccstatusline's plain text mode. `│` separator between
#     segments is only available in `tui` (grid mode); flip `display.style`
#     and add `tui.separator.column = " │ "` if that look is wanted.
#   - per-segment colors only honour hex when `theme = "custom"`.
{
  pkgs,
  lib,
  config,
  ...
}: let
  # Pin upstream. Bump → recompile on next launch (cache key is version).
  claudePowerlineVersion = "1.26.0";
  claudePowerlinePkg = "@owloops/claude-powerline";

  claudePowerline = pkgs.writeShellApplication {
    name = "claude-powerline";
    runtimeInputs = [pkgs.bun pkgs.coreutils pkgs.jq];
    text = ''
      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-powerline"
      bin_dir="$cache_root/bin-v${claudePowerlineVersion}"
      bin="$bin_dir/claude-powerline"

      if [ ! -x "$bin" ]; then
        # One-shot compile. Logged to stderr only — Claude Code reads stdout
        # for the status line, so build chatter must not bleed into it.
        {
          echo "claude-powerline: compiling ${claudePowerlinePkg}@${claudePowerlineVersion} (first run only)…"
          rm -rf "$bin_dir"
          mkdir -p "$bin_dir"
          work="$cache_root/build-v${claudePowerlineVersion}"
          rm -rf "$work"
          mkdir -p "$work"
          cd "$work"
          # Isolated install — no global pollution, deterministic per version.
          export BUN_INSTALL_CACHE_DIR="$cache_root/bun-cache"
          bun init -y >/dev/null
          bun add "${claudePowerlinePkg}@${claudePowerlineVersion}" --exact
          entry="$work/node_modules/${claudePowerlinePkg}/dist/index.mjs"
          if [ ! -f "$entry" ]; then
            # Fall back to whatever the package's `bin` field points at.
            entry="$work/node_modules/${claudePowerlinePkg}/$(jq -r '.bin["claude-powerline"] // .bin' "$work/node_modules/${claudePowerlinePkg}/package.json")"
          fi
          bun build --compile --minify --target=bun "$entry" --outfile "$bin"
          chmod +x "$bin"
          rm -rf "$work"
        } >&2
      fi

      # Inject `effort.level` fallback into the stdin payload Claude Code
      # hands the statusline. claude-powerline's `thinking` segment is
      # hidden until that key is present, and Claude Code 2.1.x only emits
      # it after the user runs `/effort <level>` in-session — even when
      # ~/.claude/settings.json has `effortLevel` set. Source the default
      # from the (possibly overlay) settings.json so the displayed effort
      # tracks `claude.nix:settings.effortLevel` and any mid-session
      # `/effort` toggle (which mutates the overlay's writable settings).
      settings_dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      default_effort=$(jq -r '.effortLevel // "high"' "$settings_dir/settings.json" 2>/dev/null || printf 'high')
      payload=$(cat)
      patched=$(printf '%s' "$payload" | jq -c --arg eff "$default_effort" '.effort.level //= $eff' 2>/dev/null) || patched=$payload

      # Run the compiled binary, capture stdout, drop every trailing
      # whitespace-only line, emit the bar with exactly one trailing
      # newline.
      set +e
      output=$(printf '%s' "$patched" | "$bin" "$@")
      status=$?
      set -e
      trimmed=$(printf '%s\n' "$output" | awk '
        { lines[NR]=$0 }
        END {
          last = NR
          while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
          for (i = 1; i <= last; i++) print lines[i]
        }
      ')

      # Append the caveman badge — `[CAVEMAN:MODE] <savings>` — to the bar
      # tail. caveman ships its own statusline script that reads two flag
      # files written by its UserPromptSubmit / mode-tracker hooks. We
      # invoke it here so claude-powerline's segments and caveman's badge
      # share one row (Claude Code renders each stdout line as a status
      # row — emitting on a second line would create a vertical gap).
      caveman_script="$HOME/.claude/plugins/marketplaces/caveman/hooks/caveman-statusline.sh"
      caveman_badge=""
      if [ -r "$caveman_script" ]; then
        caveman_badge=$(bash "$caveman_script" 2>/dev/null || true)
      fi
      if [ -n "$caveman_badge" ]; then
        printf '%s %s\n' "$trimmed" "$caveman_badge"
      else
        printf '%s\n' "$trimmed"
      fi
      exit "$status"
    '';
  };

  palette = config.theme.palette;

  # Same colour assignments as the old ccstatusline mapping — bright-ANSI band,
  # tuned for the dark `bg = #131313`.
  c = {
    model = palette.color14; # muted teal
    effort = palette.color11; # warm wheat
    context = palette.color13; # soft pink
    branch = palette.color10; # mint
    cwd = palette.color4; # accent blue
    block = palette.color9; # muted red — usage/limit semantics
  };

  # Hand-rolled JSON. claude-powerline iterates `segments` in JS insertion
  # order; Nix's `builtins.toJSON` of an attrset would alphabetise the keys
  # and silently re-order the bar. Edit this template — keep the trailing
  # commas correct and the segment block in the desired left-to-right order.
  #
  # Layout:
  #   model · thinking · context % · git branch · cwd · usage block
  configJson = ''
    {
      "theme": "custom",
      "display": {
        "padding": 1,
        "style": "minimal",
        "charset": "unicode",
        "lines": [
          {
            "segments": {
              "model":     {"enabled": true},
              "thinking":  {"enabled": true, "showEnabled": false, "showEffort": true},
              "context":   {"enabled": true, "showPercentageOnly": true, "displayStyle": "text", "percentageMode": "used"},
              "git":       {"enabled": true, "showSha": false, "showWorkingTree": false},
              "directory": {"enabled": true, "style": "full"},
              "block":     {"enabled": true, "displayStyle": "text"}
            }
          }
        ]
      },
      "colors": {
        "custom": {
          "model":     {"bg": "transparent", "fg": "${c.model}", "bold": true},
          "thinking":  {"bg": "transparent", "fg": "${c.effort}"},
          "context":   {"bg": "transparent", "fg": "${c.context}"},
          "git":       {"bg": "transparent", "fg": "${c.branch}"},
          "directory": {"bg": "transparent", "fg": "${c.cwd}"},
          "block":     {"bg": "transparent", "fg": "${c.block}"}
        }
      }
    }
  '';
in {
  home.packages = [claudePowerline];

  # Read-only declarative settings. Nix-store symlink — any in-tool save
  # attempt fails silently; edit the `configJson` template above instead.
  xdg.configFile."claude-powerline/config.json".text = configJson;
}
