#!/usr/bin/env bash
# Claude Code status line — two rows.
#
#   line 1:  ✦ model │ ◆ effort │ 󰉋 dir │ 󰘬 branch +staged ~modified ?untracked ↑ahead ↓behind
#   line 2:  ███░░░░░░░ NN% │ 󰥔 5h: NN% Xh Ym │ 7d: NN% │ ⧗ dur │ +added -removed │ [CAVEMAN] ⛏ Nk
#
# Claude Code pipes the session-state JSON on stdin after every assistant
# message; stdout becomes the status line (one terminal row per line).
#
# NOTE: deliberately NOT `set -e` — the `((X++))` idiom returns 1 when X was 0,
# which would abort the script mid-render.
set -uo pipefail

input=$(cat)
NOW=$(date +%s)

# ─── Colors (hex injected from config.theme.palette by default.nix) ────────
hex() {
  local h=${1#\#}
  printf '\033[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}
RST=$'\033[0m'

C_MODEL=$(hex "$SL_C_MODEL")
C_EFFORT_LOW=$(hex "$SL_C_EFFORT_LOW")
C_EFFORT_MED=$(hex "$SL_C_EFFORT_MED")
C_EFFORT_HIGH=$(hex "$SL_C_EFFORT_HIGH")
C_EFFORT_MAX=$(hex "$SL_C_EFFORT_MAX")
C_DIR=$(hex "$SL_C_DIR")
C_GIT=$(hex "$SL_C_GIT")
C_ADD=$(hex "$SL_C_ADD")
C_MOD=$(hex "$SL_C_MOD")
C_UNTRACKED=$(hex "$SL_C_UNTRACKED")
C_UPSTREAM=$(hex "$SL_C_UPSTREAM")
C_OK=$(hex "$SL_C_OK")
C_WARN=$(hex "$SL_C_WARN")
C_CRIT=$(hex "$SL_C_CRIT")
C_RATE=$(hex "$SL_C_RATE")
C_METRICS=$(hex "$SL_C_METRICS")
C_DIM=$(hex "$SL_C_DIM")
C_SEP=$(hex "$SL_C_SEP")

SEP=" ${C_SEP}│${RST} "

# ─── Parse the payload (single jq call — this runs on every message) ───────
{
  read -r MODEL
  read -r DIR
  read -r PCT_RAW
  read -r CTX_SIZE
  read -r FIVE_PCT
  read -r FIVE_RESET
  read -r SEVEN_PCT
  read -r DUR_MS
  read -r LINES_ADDED
  read -r LINES_REMOVED
  read -r EFFORT_IN
  read -r TRANSCRIPT
} < <(printf '%s' "$input" | jq -r '
  (.model.display_name // "—"),
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // ""),
  (.context_window.context_window_size // 200000),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.cost.total_duration_ms // 0),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.effort.level // ""),
  (.transcript_path // "")
' 2>/dev/null)

# ─── Effort ───────────────────────────────────────────────────────────────
# Claude Code only emits `.effort.level` after an in-session `/effort`, so fall
# back to the (possibly overlay) settings.json the session actually booted
# with — tracks claude.nix:settings.effortLevel and any mid-session toggle.
EFFORT=$EFFORT_IN
if [[ -z $EFFORT || $EFFORT == null ]]; then
  settings_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
  EFFORT=$(jq -r '.effortLevel // ""' "$settings_dir/settings.json" 2>/dev/null)
fi
[[ -z $EFFORT || $EFFORT == null ]] && EFFORT=$SL_DEFAULT_EFFORT

case "$EFFORT" in
low) EFFORT_SEG="${C_EFFORT_LOW}▽ low${RST}" ;;
high) EFFORT_SEG="${C_EFFORT_HIGH}▲ high${RST}" ;;
max) EFFORT_SEG="${C_EFFORT_MAX}⬆ max${RST}" ;;
xhigh) EFFORT_SEG="${C_EFFORT_MAX}⬆ xhigh${RST}" ;;
auto) EFFORT_SEG="${C_EFFORT_MED}◆ auto${RST}" ;;
*) EFFORT_SEG="${C_EFFORT_MED}◆ med${RST}" ;;
esac

# ─── Directory (full path, home-relative, clickable OSC 8) ────────────────
DIR_SEG=""
if [[ -n $DIR ]]; then
  DNAME=$DIR
  [[ $DNAME == "$HOME"/* ]] && DNAME="~${DNAME#"$HOME"}"
  [[ $DNAME == "$HOME" ]] && DNAME="~"
  DIR_SEG="${C_DIR}󰉋 "$'\033]8;;file://'"${DIR}"$'\033\\'"${DNAME}"$'\033]8;;\033\\'"${RST}"
fi

# ─── Git (cached 5s, keyed by dir) ────────────────────────────────────────
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

GIT=""
if [[ -n $DIR ]]; then
  CF="${XDG_RUNTIME_DIR:-/tmp}/claude-statusline-$(printf '%s' "$DIR" | cksum | cut -d' ' -f1)"
  BRANCH="" STAGED=0 MODIFIED=0 UNTRACKED=0 AHEAD=0 BEHIND=0
  CF_AGE=$(($(mtime "$CF" 2>/dev/null || echo 0)))
  if [[ -f $CF ]] && ((NOW - CF_AGE < 5)); then
    IFS=$'\t' read -r BRANCH STAGED MODIFIED UNTRACKED AHEAD BEHIND <"$CF"
  elif git -C "$DIR" -c gc.auto=0 rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r l; do
      case "$l" in
        '## '*)
          hdr=${l#'## '}
          BRANCH=${hdr%%...*}
          [[ $BRANCH == "HEAD (no branch)" ]] && BRANCH="detached"
          # "## main...origin/main [ahead 2, behind 1]"
          if [[ $hdr == *'[ahead '* ]]; then
            tmp=${hdr##*'[ahead '}
            AHEAD=${tmp%%[,\]]*}
          fi
          if [[ $hdr == *'behind '* ]]; then
            tmp=${hdr##*'behind '}
            BEHIND=${tmp%%[,\]]*}
          fi
          ;;
        '??'*) ((UNTRACKED++)) ;;
        *)
          [[ ${l:0:1} != ' ' ]] && ((STAGED++))
          [[ ${l:1:1} != ' ' ]] && ((MODIFIED++))
          ;;
      esac
    done < <(git -C "$DIR" -c gc.auto=0 status --porcelain -b 2>/dev/null)
    printf '%s\t%s\t%s\t%s\t%s\t%s' \
      "$BRANCH" "$STAGED" "$MODIFIED" "$UNTRACKED" "$AHEAD" "$BEHIND" >"$CF"
  fi
  if [[ -n $BRANCH ]]; then
    GIT="${SEP}${C_GIT}󰘬 ${BRANCH}${RST}"
    ((STAGED > 0)) && GIT+=" ${C_ADD}+${STAGED}${RST}"
    ((MODIFIED > 0)) && GIT+=" ${C_MOD}~${MODIFIED}${RST}"
    ((UNTRACKED > 0)) && GIT+=" ${C_UNTRACKED}?${UNTRACKED}${RST}"
    ((AHEAD > 0)) && GIT+=" ${C_UPSTREAM}↑${AHEAD}${RST}"
    ((BEHIND > 0)) && GIT+=" ${C_UPSTREAM}↓${BEHIND}${RST}"
  fi
fi

# ═══ LINE 1 ═══════════════════════════════════════════════════════════════
LINE1="${C_MODEL}✦ ${MODEL}${RST}${SEP}${EFFORT_SEG}"
[[ -n $DIR_SEG ]] && LINE1+="${SEP}${DIR_SEG}"
LINE1+="$GIT"
printf '%s\n' "$LINE1"

# ─── Context bar ──────────────────────────────────────────────────────────
# `.context_window` is absent on older Claude Code builds; fall back to the
# last `usage` block in this session's transcript (what claude-powerline did).
if [[ -z $PCT_RAW || $PCT_RAW == null ]] && [[ -n $TRANSCRIPT && -r $TRANSCRIPT ]]; then
  used=$(tac "$TRANSCRIPT" 2>/dev/null | grep -m1 '"usage"' |
    jq -r '[.message.usage // {} | .input_tokens, .cache_read_input_tokens,
            .cache_creation_input_tokens, .output_tokens]
           | map(. // 0) | add' 2>/dev/null)
  if [[ -n ${used:-} && $used != null ]] && ((CTX_SIZE > 0)); then
    PCT_RAW=$((used * 100 / CTX_SIZE))
  fi
fi

PCT=0
if [[ -n $PCT_RAW && $PCT_RAW != null ]]; then
  PCT=${PCT_RAW%%.*}
  [[ $PCT =~ ^[0-9]+$ ]] || PCT=0
  ((PCT < 0)) && PCT=0
  ((PCT > 100)) && PCT=100
fi
if ((PCT >= 60)); then
  BC=$C_CRIT
elif ((PCT >= 40)); then
  BC=$C_WARN
else
  BC=$C_OK
fi

F=$((PCT / 10))
E=$((10 - F))
BAR=""
for ((i = 0; i < F; i++)); do BAR+="█"; done
for ((i = 0; i < E; i++)); do BAR+="░"; done

# ─── 5h rate limit + reset countdown ──────────────────────────────────────
RLIM=""
if [[ -n $FIVE_PCT && $FIVE_PCT != null ]]; then
  FI=$(printf '%.0f' "$FIVE_PCT" 2>/dev/null || echo 0)
  if ((FI >= 80)); then
    RC=$C_CRIT
  elif ((FI >= 50)); then
    RC=$C_WARN
  else
    RC=$C_RATE
  fi
  RLIM="${SEP}${RC}󰥔 5h: ${FI}%${RST}"
  if [[ -n $FIVE_RESET && $FIVE_RESET != null ]]; then
    # resets_at is epoch seconds on current builds; tolerate an ISO-8601 string.
    if [[ $FIVE_RESET =~ ^[0-9]+$ ]]; then
      RESET_TS=$FIVE_RESET
    else
      RESET_TS=$(date -d "$FIVE_RESET" +%s 2>/dev/null || echo 0)
    fi
    REM=$((RESET_TS - NOW))
    ((REM > 0)) && RLIM+=" ${C_DIM}$((REM / 3600))h$(((REM % 3600) / 60))m${RST}"
  fi
fi

# ─── 7d rate limit ────────────────────────────────────────────────────────
if [[ -n $SEVEN_PCT && $SEVEN_PCT != null ]]; then
  SI=$(printf '%.0f' "$SEVEN_PCT" 2>/dev/null || echo 0)
  if ((SI >= 80)); then
    SC=$C_CRIT
  elif ((SI >= 50)); then
    SC=$C_WARN
  else
    SC=$C_DIM
  fi
  RLIM+="${SEP}${SC}7d: ${SI}%${RST}"
fi

# ─── Metrics: session duration + lines ± ──────────────────────────────────
fmt_dur() {
  local s=$(($1 / 1000))
  if ((s >= 3600)); then
    printf '%dh%dm' $((s / 3600)) $(((s % 3600) / 60))
  elif ((s >= 60)); then
    printf '%dm%ds' $((s / 60)) $((s % 60))
  else
    printf '%ds' "$s"
  fi
}

MET=""
[[ $DUR_MS =~ ^[0-9]+$ ]] || DUR_MS=0
((DUR_MS > 0)) && MET="${SEP}${C_METRICS}⧗ $(fmt_dur "$DUR_MS")${RST}"
[[ $LINES_ADDED =~ ^[0-9]+$ ]] || LINES_ADDED=0
[[ $LINES_REMOVED =~ ^[0-9]+$ ]] || LINES_REMOVED=0
if ((LINES_ADDED > 0 || LINES_REMOVED > 0)); then
  MET+="${SEP}${C_ADD}+${LINES_ADDED}${RST} ${C_CRIT}-${LINES_REMOVED}${RST}"
fi

# ─── Caveman badge ────────────────────────────────────────────────────────
# Upstream ships its own statusline fragment reading the mode + savings flags
# from $CLAUDE_CONFIG_DIR (per-session overlay). Probe both plugin layouts —
# upstream moved the script under src/ at some point.
CAVEMAN=""
for caveman_script in \
  "$HOME/.claude/plugins/marketplaces/caveman/src/hooks/caveman-statusline.sh" \
  "$HOME/.claude/plugins/marketplaces/caveman/hooks/caveman-statusline.sh"; do
  if [[ -r $caveman_script ]]; then
    badge=$(bash "$caveman_script" 2>/dev/null || true)
    [[ -n $badge ]] && CAVEMAN="${SEP}${badge}"
    break
  fi
done

# ═══ LINE 2 ═══════════════════════════════════════════════════════════════
printf '%s\n' "${BC}${BAR}${RST} ${PCT}%${RLIM}${MET}${CAVEMAN}"
