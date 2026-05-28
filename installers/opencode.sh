#!/usr/bin/env bash
# opencode — sst/opencode (npm: opencode-ai). Install/update. Binary: `opencode`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

require_cmd npm
PKG="opencode-ai"

if command -v opencode >/dev/null 2>&1 && npm list -g --depth=0 "$PKG" >/dev/null 2>&1; then
  log "opencode: present — updating to latest"
  npm install -g "${PKG}@latest" 2>&1 | tail -3 || { warn "opencode: update failed"; exit 1; }
else
  log "opencode: installing"
  npm install -g "$PKG" 2>&1 | tail -3 || { warn "opencode: install failed"; exit 1; }
fi

command -v opencode >/dev/null 2>&1 \
  && ok "opencode ready: $(opencode --version 2>/dev/null || echo installed)" \
  || warn "opencode: installed but not on PATH"
