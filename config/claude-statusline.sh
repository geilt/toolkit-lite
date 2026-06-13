#!/bin/bash
# Claude Code Status Line — TLD Platform
# Line 1: [hostname] · dir · branch (if git) · model
# Line 2: ████░░░░░░ XX% context · $X.XX · Xm · +N/-N lines

INPUT=$(cat)

# ── Parse JSON fields ──────────────────────────────────────
eval "$(echo "$INPUT" | jq -r '
  @sh "MODEL=\(.model.display_name // "Claude")",
  @sh "PCT_RAW=\(.context_window.used_percentage // 0)",
  @sh "COST=\(.cost.total_cost_usd // 0)",
  @sh "DURATION_MS=\(.cost.total_duration_ms // 0)",
  @sh "LINES_ADD=\(.cost.total_lines_added // 0)",
  @sh "LINES_DEL=\(.cost.total_lines_removed // 0)",
  @sh "CWD=\(.cwd // ".")"
')"

# ── Runtime values ────────────────────────────────────────
HOST=$(hostname -s)
DIR=$(basename "$CWD")

# ── Sanitize percentage ───────────────────────────────────
PCT=${PCT_RAW%.*}
PCT=${PCT:-0}
[ "$PCT" -lt 0 ] 2>/dev/null && PCT=0
[ "$PCT" -gt 100 ] 2>/dev/null && PCT=100

# ── ANSI colors ───────────────────────────────────────────
G='\033[32m'   # green
Y='\033[33m'   # yellow
R='\033[31m'   # red
B='\033[1m'    # bold
D='\033[2m'    # dim
Z='\033[0m'    # reset

# ── Context bar color (conservative thresholds) ──────────
if [ "$PCT" -lt 50 ]; then
    C="$G"
elif [ "$PCT" -lt 75 ]; then
    C="$Y"
else
    C="$R"
fi

# ── Progress bar (10 segments) ────────────────────────────
FILLED=$((PCT * 10 / 100))
[ "$FILLED" -gt 10 ] && FILLED=10
EMPTY=$((10 - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v F "%${FILLED}s" "" && BAR="${F// /█}"
[ "$EMPTY"  -gt 0 ] && printf -v E "%${EMPTY}s"  "" && BAR="${BAR}${E// /░}"

# ── Duration formatting ──────────────────────────────────
DS=$((DURATION_MS / 1000))
DM=$((DS / 60))
if [ "$DM" -ge 60 ]; then
    DH=$((DM / 60)); DM=$((DM % 60))
    DFMT="${DH}h${DM}m"
elif [ "$DM" -gt 0 ]; then
    DFMT="${DM}m"
else
    DFMT="${DS}s"
fi

# ── Cost formatting ──────────────────────────────────────
CFMT=$(printf '$%.2f' "$COST")

# ── Git branch (5-second cache) ───────────────────────────
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR" 2>/dev/null
CACHE_KEY=$(echo -n "$CWD" | md5 | awk '{print $NF}')
CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

GIT_BRANCH="" GIT_STAGED=0 GIT_MODIFIED=0 GIT_STASH=0

if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
    NOW=$(date +%s)
    CACHE_AGE=999
    [ -f "$CACHE_FILE" ] && CACHE_AGE=$(( NOW - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))

    if [ "$CACHE_AGE" -lt 5 ]; then
        source "$CACHE_FILE"
    else
        GIT_BRANCH=$(git --no-optional-locks -C "$CWD" branch --show-current 2>/dev/null || echo "")
        GIT_STAGED=$(git --no-optional-locks -C "$CWD" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        GIT_MODIFIED=$(git --no-optional-locks -C "$CWD" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        GIT_STASH=$(git --no-optional-locks -C "$CWD" stash list 2>/dev/null | wc -l | tr -d ' ')
        cat > "$CACHE_FILE" <<CACHE
GIT_BRANCH="$GIT_BRANCH"
GIT_STAGED=$GIT_STAGED
GIT_MODIFIED=$GIT_MODIFIED
GIT_STASH=$GIT_STASH
CACHE
    fi
fi

# ── LINE 1: [hostname] · dir · branch · model ────────────
SEP="${D} · ${Z}"
L1="${B}[${HOST}]${Z}${SEP}${DIR}"
[ -n "$GIT_BRANCH" ] && L1="${L1}${SEP}${GIT_BRANCH}"
L1="${L1}${SEP}${D}${MODEL}${Z}"
printf '%b\n' "$L1"

# ── LINE 2: Context bar · cost · duration · LOC ──────────
L2="${C}${BAR}${Z} ${C}${PCT}%${Z}"
L2="${L2}${SEP}${CFMT}${SEP}${DFMT}"
if [ "$GIT_STAGED" -gt 0 ] || [ "$GIT_MODIFIED" -gt 0 ]; then
    L2="${L2}${SEP}${G}✔ ${GIT_STAGED}${Z} ${Y}✎ ${GIT_MODIFIED}${Z}"
fi
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
    L2="${L2}${SEP}${G}+${LINES_ADD}${Z}/${R}-${LINES_DEL}${Z}"
fi
printf '%b\n' "$L2"
