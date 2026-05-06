# `ccstatusline` — declarative Claude Code status line.
#
# Two pieces:
#   1. Light `ccstatusline` CLI shim (lazy `npx ccstatusline@<pinned>`),
#      same pattern as `ruflo-cli.nix` / `ccmanager.nix`. No build-time npm
#      closure — first invocation downloads under $XDG_CACHE_HOME/ccstatusline/.
#   2. Declarative `~/.config/ccstatusline/settings.json` rendered from the
#      `cfg` attrset below (read-only nix-store symlink, like ccmanager's
#      config). The `ccstatusline` TUI's "save" path silently fails on the
#      read-only symlink — edit the attrset here and `scripts/nix_switch`.
#
# Wiring into Claude Code lives in `claude.nix` via
# `programs.claude-code.settings.statusLine`. We pass `command = "ccstatusline"`
# (PATH lookup) so launchers under `claude-launchers.nix` inherit it without
# baking a store path into the config.
#
# Colors come straight from `config.theme.palette` via ccstatusline's
# `hex:RRGGBB` literal (only honoured when `colorLevel = 3` / truecolor —
# see `src/utils/colors.ts:getChalkColor`). That keeps the bar in sync with
# kitty / ghostty / starship instead of drifting into chalk's default ANSI.
#
# Schema reference:
#   - top-level Settings: github.com/sirmalloc/ccstatusline src/types/Settings.ts
#   - widget type strings: src/utils/widget-manifest.ts (`WIDGET_MANIFEST`)
{
  pkgs,
  lib,
  config,
  ...
}: let
  # Track upstream's `latest` by convention; pin to a specific version if a
  # release breaks the schema.
  ccstatuslineVersion = "latest";

  ccstatusline = pkgs.writeShellApplication {
    name = "ccstatusline";
    runtimeInputs = [pkgs.nodejs_20];
    text = ''
      export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ccstatusline/npm-cache"
      export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/ccstatusline/npm-prefix"
      mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
      exec npx --yes "ccstatusline@${ccstatuslineVersion}" "$@"
    '';
  };

  palette = config.theme.palette;
  # ccstatusline's `hex:` literal is bare hex (no leading `#`).
  hex = h: "hex:" + lib.removePrefix "#" h;

  # Pull from the bright-ANSI band so widgets pop on the dark `bg = #131313`
  # without screaming.
  c = {
    model = hex palette.color14; # muted teal — Claude/cyan accent
    effort = hex palette.color11; # warm wheat — "thinking" cue
    context = hex palette.color13; # soft pink — distinct from branch
    branch = hex palette.color10; # mint — git
    cwd = hex palette.color4; # accent blue (#89ceff, also `url`)
  };

  # Single-line layout, in order:
  #   model · effort · ctx% · git branch · cwd
  # No explicit `separator` widgets — `defaultSeparator` auto-inserts a
  # divider between adjacent data widgets. (Adding explicit separators on
  # top of `defaultSeparator` doubles the divider.)
  cfg = {
    version = 3;
    # One blank row below the data line, separating it from Claude Code's
    # mode indicator ("bypass permissions on …"). ccstatusline's renderer
    # (`src/ccstatusline.ts:205-213`) drops any line whose visible text
    # `.trim()`s to empty before `console.log`; JS `.trim()` strips NBSP
    # (U+00A0) too. U+2800 BRAILLE PATTERN BLANK is invisible but *not*
    # whitespace, so the spacer survives the filter.
    lines = [
      [
        {
          id = "1";
          type = "model";
          color = c.model;
          bold = true;
        }
        {
          id = "3";
          type = "thinking-effort";
          color = c.effort;
        }
        {
          id = "5";
          type = "context-percentage";
          color = c.context;
        }
        {
          id = "7";
          type = "git-branch";
          color = c.branch;
        }
        {
          id = "9";
          type = "current-working-dir";
          color = c.cwd;
        }
      ]
      [
        {
          id = "spacer-bottom-1";
          type = "custom-text";
          customText = "⠀";
        }
      ]
      [
        {
          id = "spacer-bottom-2";
          type = "custom-text";
          customText = "⠀";
        }
      ]
    ];
    flexMode = "full-minus-40";
    compactThreshold = 60;
    # 3 = truecolor; required for `hex:` literals to render.
    colorLevel = 3;
    defaultSeparator = " │ ";
    defaultPadding = " ";
    # When true the divider takes on the adjacent widget's colour (gradient
    # of sorts). False keeps it at chalk's default fg, which on this palette
    # reads as a neutral light grey — good enough without a per-separator
    # widget.
    inheritSeparatorColors = false;
    globalBold = false;
    minimalistMode = false;
    powerline = {
      enabled = false;
      separators = [""];
      separatorInvertBackground = [false];
      startCaps = [];
      endCaps = [];
      autoAlign = false;
      continueThemeAcrossLines = false;
    };
  };
in {
  home.packages = [ccstatusline];

  # Read-only declarative settings. Nix-store symlink — TUI edits silently
  # fail on save (same trade-off as ccmanager's read-only config).
  xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON cfg;
}
