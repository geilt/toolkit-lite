#!/usr/bin/env bash
# kimi — Moonshot Kimi Code CLI. Install/update. Binary: `kimi` (or `kimi-code`).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

existing=""
for b in kimi kimi-code; do
  command -v "$b" >/dev/null 2>&1 && { existing="$b"; break; }
done

if [ -n "$existing" ]; then
  log "kimi: present as '$existing' — re-running installer to update"
else
  log "kimi: installing"
fi

curl -L code.kimi.com/install.sh | bash || { warn "kimi: installer failed"; exit 1; }

for b in kimi kimi-code; do
  command -v "$b" >/dev/null 2>&1 && { ok "kimi ready: $(command -v "$b")"; exit 0; }
done
warn "kimi: installed but neither 'kimi' nor 'kimi-code' on PATH — confirm the binary name"
