# `claude-statusline` — Claude Code status line (replaces claude-powerline).
#
# A plain bash script fed by the JSON Claude Code pipes on stdin after every
# assistant message. Layout follows
# https://rdiachenko.com/til/claude-code/custom-statusline/ (two rows, Nerd
# Font icons, OSC 8 clickable dir, 5s-cached git), extended to carry every
# segment the previous claude-powerline bar showed:
#
#   line 1:  ✦ model │ ◆ effort │ 󰉋 dir │ 󰘬 branch +staged ~modified ?untracked ↑↓
#   line 2:  ███░░░░░░░ NN% │ 󰥔 5h: NN% Xh Ym │ 7d: NN% │ ⧗ dur │ +N -N │ [CAVEMAN] ⛏ Nk
#
# vs claude-powerline: same model / effort / context % / git (tree + upstream)
# / directory / metrics (duration + lines ±) / 5h usage block / caveman badge,
# plus the post's 7d rate limit and context bar. Dropped: the powerline `▶`
# arrow caps and filled colour blocks (this is the post's "minimal" look —
# colour on glyphs, `│` separators), and the post's USD cost segment
# (meaningless on a flat-rate plan — same reasoning as the `caveman stats`
# wrapper, which also hides cost).
#
# Why not claude-powerline any more: it needed a first-run `bun install` +
# `bun build --compile` (~5-10 s) and a cached ~100 MB binary per version.
# This is ~5 ms of bash + one jq call, no cache, no npm.
#
# Colours come from `config.theme.palette`, injected as `SL_C_*` hex env vars
# (the script converts to truecolor ANSI). To match the blog post exactly,
# swap the `c` attrset below for Catppuccin Macchiato hexes.
#
# Wired into Claude Code in `claude.nix` via
# `programs.claude-code.settings.statusLine.command = "claude-statusline"`
# (PATH lookup, so `claude-launchers/` wrappers inherit it).
{
  pkgs,
  config,
  ...
}: let
  palette = config.theme.palette;

  # Effort shown when neither the payload's `.effort.level` nor the session's
  # settings.json carries one. Keep aligned with claude.nix:settings.effortLevel.
  defaultEffort = "high";

  c = {
    model = palette.color14; # muted teal
    effortLow = palette.fg_dim;
    effortMed = palette.color11; # warm wheat
    effortHigh = palette.color9; # muted rose
    effortMax = palette.color13; # soft pink
    dir = palette.color4; # accent blue
    git = palette.color10; # mint
    add = palette.color10; # mint — staged / lines added
    mod = palette.color11; # wheat — modified
    untracked = palette.fg_dim;
    upstream = palette.color14; # teal — ahead/behind
    ok = palette.color10; # context/rate < 40%
    warn = palette.color11; # 40-60%
    crit = palette.color9; # > 60%, and lines removed
    rate = palette.color12; # soft violet — 5h block under threshold
    metrics = palette.color12; # soft violet — duration
    dim = palette.fg_dim; # reset countdown, 7d limit
    sep = palette.color0; # `│` separators
  };

  # Script bundled as a real `.sh` (shellcheck-clean, LSP-friendly); every
  # nix-side value enters through an env var — repo-wide convention, see
  # `ai/CLAUDE.md` → "Embedded-script extraction pattern".
  scriptDir = pkgs.runCommand "claude-statusline-scripts" {} ''
    mkdir -p $out
    cp -r ${./scripts}/* $out/
    chmod +x $out/statusline.sh
  '';

  claudeStatusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [bash jq git coreutils gnugrep];
    text = ''
      export SL_C_MODEL="${c.model}"
      export SL_C_EFFORT_LOW="${c.effortLow}"
      export SL_C_EFFORT_MED="${c.effortMed}"
      export SL_C_EFFORT_HIGH="${c.effortHigh}"
      export SL_C_EFFORT_MAX="${c.effortMax}"
      export SL_C_DIR="${c.dir}"
      export SL_C_GIT="${c.git}"
      export SL_C_ADD="${c.add}"
      export SL_C_MOD="${c.mod}"
      export SL_C_UNTRACKED="${c.untracked}"
      export SL_C_UPSTREAM="${c.upstream}"
      export SL_C_OK="${c.ok}"
      export SL_C_WARN="${c.warn}"
      export SL_C_CRIT="${c.crit}"
      export SL_C_RATE="${c.rate}"
      export SL_C_METRICS="${c.metrics}"
      export SL_C_DIM="${c.dim}"
      export SL_C_SEP="${c.sep}"
      export SL_DEFAULT_EFFORT=${defaultEffort}
      exec bash ${scriptDir}/statusline.sh "$@"
    '';
  };
in {
  home.packages = [claudeStatusline];
}
