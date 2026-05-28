#!/usr/bin/env bash
# cursor — Cursor CLI agent. Install/update. Binary: `cursor-agent`.
# Adds a convenience `cursor -> cursor-agent` symlink in ~/.local/bin.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if [ -x "$HOME/.local/bin/cursor-agent" ]; then
  log "cursor: present — re-running installer to update"
else
  log "cursor: installing (binary: cursor-agent)"
fi

curl https://cursor.com/install -fsS | bash || { warn "cursor: installer failed"; exit 1; }

if [ -x "$HOME/.local/bin/cursor-agent" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sfn cursor-agent "$HOME/.local/bin/cursor"   # relative symlink within ~/.local/bin
  ok "cursor ready: $HOME/.local/bin/cursor-agent (aliased as 'cursor')"
else
  warn "cursor: installed but cursor-agent not in ~/.local/bin"
fi
