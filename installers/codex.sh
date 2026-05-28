#!/usr/bin/env bash
# codex — OpenAI Codex CLI (npm: @openai/codex). Install/update. Binary: `codex`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

load_node   # ensure nvm's node/npm is on PATH even when run from install.sh
require_cmd npm
PKG="@openai/codex"

if command -v codex >/dev/null 2>&1 && npm list -g --depth=0 "$PKG" >/dev/null 2>&1; then
  log "codex: present — updating to latest"
  npm i -g "${PKG}@latest" || { warn "codex: update failed"; exit 1; }
else
  log "codex: installing"
  npm i -g "$PKG" || { warn "codex: install failed"; exit 1; }
fi

command -v codex >/dev/null 2>&1 \
  && ok "codex ready: $(codex --version 2>/dev/null || echo installed)" \
  || warn "codex: installed but not on PATH"
