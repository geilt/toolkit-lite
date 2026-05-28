#!/usr/bin/env bash
# acli — Atlassian CLI (Jira / Confluence / Bitbucket). Install/update.
# Binary: `acli`. Official tap: atlassian/homebrew-acli.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if [ "$(os)" = "macos" ]; then
  ensure_brew_on_path || { warn "acli: brew missing"; exit 1; }
  brew tap atlassian/homebrew-acli >/dev/null 2>&1 || true
  if brew list acli >/dev/null 2>&1; then
    log "acli: present — updating"
    brew upgrade acli 2>/dev/null || true
  else
    log "acli: installing (tap atlassian/homebrew-acli)"
    brew install acli || { warn "acli: install failed — see https://developer.atlassian.com/cloud/acli/guides/install-acli/"; exit 1; }
  fi
else
  warn "acli: automated Linux install not wired up — see https://developer.atlassian.com/cloud/acli/guides/install-acli/"
  exit 0
fi

command -v acli >/dev/null 2>&1 \
  && ok "acli ready: $(acli --version 2>/dev/null | head -1 || echo installed)" \
  || warn "acli: not on PATH"
