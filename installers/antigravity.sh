#!/usr/bin/env bash
# antigravity — Google Antigravity CLI (replaces the deprecated gemini-cli).
# Install/update. Binary is `antigravity` (older builds: `gemini`).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

existing=""
for b in antigravity gemini; do
  command -v "$b" >/dev/null 2>&1 && { existing="$b"; break; }
done

if [ -n "$existing" ]; then
  log "antigravity: present as '$existing' — re-running installer to update"
else
  log "antigravity: installing"
fi

curl -fsSL https://antigravity.google/cli/install.sh | bash || { warn "antigravity: installer failed"; exit 1; }

for b in antigravity gemini; do
  command -v "$b" >/dev/null 2>&1 && { ok "antigravity ready: $(command -v "$b")"; exit 0; }
done
warn "antigravity: installed but neither 'antigravity' nor 'gemini' on PATH — confirm the binary name"
