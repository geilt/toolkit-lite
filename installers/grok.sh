#!/usr/bin/env bash
# grok — xAI Grok CLI. Install/update. Binary installs as `agent`.
# Detected by path (not bare `command -v agent`) to avoid clobbering an
# unrelated tool also named "agent".
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

found=""
for p in "$HOME/.local/bin/agent" /usr/local/bin/agent /opt/homebrew/bin/agent; do
  [ -x "$p" ] && { found="$p"; break; }
done

if [ -n "$found" ]; then
  log "grok: present at $found — re-running installer to update"
else
  log "grok: installing (binary will be 'agent')"
fi

curl -fsSL https://x.ai/cli/install.sh | bash || { warn "grok: installer failed"; exit 1; }

for p in "$HOME/.local/bin/agent" /usr/local/bin/agent /opt/homebrew/bin/agent; do
  [ -x "$p" ] && { ok "grok ready: $p"; exit 0; }
done
warn "grok: installed but 'agent' not found in expected paths"
