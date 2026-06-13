#!/usr/bin/env bash
# claude-code — Anthropic Claude Code CLI. Install/update. Binary: `claude`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if command -v claude >/dev/null 2>&1; then
  log "claude-code: present ($(command -v claude)) — re-running installer to update"
else
  log "claude-code: installing"
fi

curl -fsSL https://claude.ai/install.sh | bash || { warn "claude-code: installer failed"; exit 1; }

if command -v claude >/dev/null 2>&1; then
  ok "claude ready: $(claude --version 2>/dev/null || echo installed)"
else
  warn "claude-code: installed but 'claude' not on PATH (check ~/.local/bin in PATH)"
fi

# Setup custom statusline if jq is available
claude_settings="$HOME/.claude/settings.json"
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude"
  log "claude-code: installing custom statusline"
  cp "$TOOLKIT_LITE_ROOT/config/claude-statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"

  [ -f "$claude_settings" ] || printf '{}\n' > "$claude_settings"
  tmp="$(mktemp)"
  if jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh", "padding": 1}' "$claude_settings" > "$tmp" 2>/dev/null; then
    [ -s "$claude_settings" ] && cp -p "$claude_settings" "$claude_settings.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    mv "$tmp" "$claude_settings"
    chmod 600 "$claude_settings" 2>/dev/null || true
    ok "claude-code: statusline configured in settings.json"
  else
    rm -f "$tmp"
    warn "claude-code: settings.json is not valid JSON; could not configure statusline"
  fi
else
  warn "claude-code: jq missing; skipping custom statusline setup"
fi
