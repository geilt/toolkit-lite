#!/usr/bin/env bash
# tmux — install tmux + a sensible ~/.tmux.conf (vi keys, mouse, status bar).
# The status bar shows a name; on first run we prompt for it, on later runs we
# reuse what's already baked into ~/.tmux.conf (no re-prompt).
#
# Config template originates from the TLD Toolkit tmux setup.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

TEMPLATE="$TOOLKIT_LITE_ROOT/config/tmux.conf.template"
TARGET="$HOME/.tmux.conf"
[ -f "$TEMPLATE" ] || die "tmux: template missing at $TEMPLATE"

# 1. Ensure tmux is installed
if ! command -v tmux >/dev/null 2>&1; then
  log "tmux: installing"
  pkg_install tmux || die "tmux: install failed"
fi
ok "tmux: $(tmux -V)"

# 2. Determine the status-bar name.
#    If TOOLKIT_LITE_USERNAME is set, use it directly (no prompt). Otherwise
#    prompt with a sensible default shown in (parens) — press Enter to accept.
#    Default priority: name chosen in the shell-prompt step → an existing
#    ~/.tmux.conf name → the system username.
#    (TOOLKIT_LIGHT_USERNAME still honored as a fallback for older callers.)
STATE_FILE="$HOME/.config/toolkit-lite/preferred-name"
username="${TOOLKIT_LITE_USERNAME:-${TOOLKIT_LIGHT_USERNAME:-}}"
if [ -z "$username" ]; then
  default=""
  [ -f "$STATE_FILE" ] && default="$(head -1 "$STATE_FILE" 2>/dev/null)"
  if [ -z "$default" ] && [ -f "$TARGET" ]; then
    default="$(sed -n 's/.*status-left .*bold\] \([a-z0-9_-]*\):tmux:.*/\1/p' "$TARGET" | head -1)"
  fi
  [ -n "$default" ] || default="$(id -un)"
  if [ -t 0 ]; then
    printf 'Name for the tmux status bar (%s): ' "$default"
    read -r raw
    username="$(printf '%s' "${raw:-$default}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  else
    username="$default"
  fi
fi
[ -n "$username" ] || username="$(id -un)"   # final fallback: system user
log "tmux: status-bar name = $username"

# 3. Render template → ~/.tmux.conf (back up an existing file first).
if [ -f "$TARGET" ]; then
  cp -p "$TARGET" "${TARGET}.bak.$(date +%Y%m%d-%H%M%S)"
fi
sed "s/__USERNAME__/$username/g" "$TEMPLATE" > "$TARGET"
ok "tmux: wrote $TARGET (reload inside tmux with: prefix + r)"

# 4. Create the 'dev' shortcut script in ~/.local/bin/dev
# Check if tldtoolkit is installed on this machine
TLD_PRESENT=0
[ -d "$HOME/environment/tldtoolkit" ] && TLD_PRESENT=1
for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  [ -f "$f" ] && grep -qi "tldtoolkit" "$f" && TLD_PRESENT=1
done

INSTALL_DEV=1
if [ "$TLD_PRESENT" -eq 1 ]; then
  if [ -t 0 ]; then
    printf '\n'
    log "Dev Command Detection"
    echo "The 'dev' command is already managed/installed by the TLD Toolkit (tldtoolkit) on this machine."
    printf "Would you like to install/overwrite the standalone version anyway under ~/.local/bin/dev? [y/N] "
    read -r ans
    case "$ans" in
      y|Y|yes|YES) INSTALL_DEV=1 ;;
      *)           INSTALL_DEV=0; log "Skipped installing standalone 'dev' command." ;;
    esac
  else
    # Non-interactive fallback when tldtoolkit is present: don't overwrite
    INSTALL_DEV=0
  fi
fi

if [ "$INSTALL_DEV" -eq 1 ]; then
  mkdir -p "$HOME/.local/bin"
  DEV_CMD="$HOME/.local/bin/dev"
  log "tmux: creating 'dev' shortcut script at $DEV_CMD"
  cat <<'EOF' > "$DEV_CMD"
#!/usr/bin/env bash
# Quick wrapper to attach to, create, list, or close dev tmux sessions.

SESSION="dev"
ACTION="attach"

case "${1:-}" in
  list|--list|-l)
    if ! command -v tmux >/dev/null 2>&1; then
      echo "tmux is not installed."
      exit 1
    fi
    # Filter sessions starting with "dev" and strip/format prefix
    sessions="$(tmux list-sessions 2>/dev/null | grep "^dev" | sed -E 's/^dev-([^:]+:)/\1/; s/^dev:/(default):/' || true)"
    if [ -z "$sessions" ]; then
      echo "No active dev tmux sessions."
    else
      echo "Active dev tmux sessions:"
      echo "$sessions"
    fi
    exit 0
    ;;
  help|--help|-h)
    echo "Usage: dev [session_name [kill|close] | list | -l | --list | kill | close]"
    echo "  Without arguments: Attaches to or creates a tmux session named 'dev'"
    echo "  <session_name>:    Attaches to or creates a tmux session named 'dev-<session_name>'"
    echo "  list, -l, --list:  Lists active tmux sessions starting with 'dev'"
    echo "  kill, close:       Closes the default tmux session named 'dev'"
    echo "  <session_name> kill|close: Closes the tmux session named 'dev-<session_name>'"
    exit 0
    ;;
  kill|close)
    SESSION="dev"
    ACTION="kill"
    ;;
  *)
    if [ -n "${1:-}" ]; then
      # Sanitize the suffix (lowercase, alphanumeric/hyphens/underscores)
      clean_suffix="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]_-')"
      SESSION="dev-${clean_suffix}"
      if [ "${2:-}" = "kill" ] || [ "${2:-}" = "close" ]; then
        ACTION="kill"
      fi
    fi
    ;;
esac

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed."
  exit 1
fi

if [ "$ACTION" = "kill" ]; then
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION"
    echo "Closed tmux session '$SESSION'."
  else
    echo "Tmux session '$SESSION' does not exist."
  fi
  exit 0
fi

printf '\033]0;tmux:%s\007' "$SESSION"
exec tmux attach-session -t "$SESSION" 2>/dev/null || exec tmux new-session -s "$SESSION"
EOF
  chmod +x "$DEV_CMD"
  ok "tmux: 'dev' command created (type 'dev' to start/attach to your 'dev' tmux session)"
fi
