#!/usr/bin/env bash
# gh — GitHub CLI. Install/update. Binary: `gh`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if command -v gh >/dev/null 2>&1; then
  log "gh: present — updating"
  if [ "$(os)" = "macos" ]; then ensure_brew_on_path && brew upgrade gh 2>/dev/null || true; fi
else
  log "gh: installing"
  pkg_install gh || { warn "gh: install failed (Debian/Ubuntu may need GitHub's apt repo — see https://cli.github.com)"; exit 1; }
fi

command -v gh >/dev/null 2>&1 \
  && ok "gh ready: $(gh --version 2>/dev/null | head -1)" \
  || warn "gh: not on PATH"
