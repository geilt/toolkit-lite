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
