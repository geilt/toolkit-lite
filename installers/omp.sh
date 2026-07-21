#!/usr/bin/env bash
# omp — Oh My Pi (omp) CLI. Install/update. Binary: `omp`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

TOOL="omp"
INSTALL_URL="https://omp.sh/install"

log "$TOOL: installing/updating"

if ! curl -fsSL "$INSTALL_URL" | sh; then
  warn "$TOOL: install failed"
  exit 1
fi

if command -v omp >/dev/null 2>&1; then
  ok "$TOOL ready: $(omp --version 2>/dev/null || echo installed)"
else
  # Common candidates if PATH is not updated yet.
  for candidate in "$HOME/.local/bin/omp" "/usr/local/bin/omp"; do
    if [ -x "$candidate" ]; then
      warn "$TOOL: binary at $candidate but not on PATH; ensure ~/.local/bin or equivalent is on PATH"
      break
    fi
  done
  exit 1
fi
