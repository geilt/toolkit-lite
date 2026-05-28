#!/usr/bin/env bash
# node — install nvm (if missing) + Node.js LTS, set as default.
# The agentic CLIs that install via npm (codex, opencode) need this first.
# Re-running upgrades npm itself and ensures the LTS is current.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

export NVM_DIR="$HOME/.nvm"

# 1. nvm
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  log "node: installing nvm"
  NVM_TAG="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
    | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
  [ -n "$NVM_TAG" ] || NVM_TAG="v0.40.1"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh" | bash \
    || die "node: nvm install failed"
else
  log "node: nvm present"
fi

# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

# 2. Node LTS
log "node: installing/updating the current LTS"
nvm install --lts
nvm alias default 'lts/*' >/dev/null
nvm use --lts >/dev/null

# 3. npm itself
npm install -g npm@latest >/dev/null 2>&1 || warn "node: npm self-update skipped"

ok "node ready: $(node -v) / npm $(npm -v)"
