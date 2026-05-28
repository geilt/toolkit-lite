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
