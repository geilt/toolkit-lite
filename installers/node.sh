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

# Determine current default node version (if any)
current_default=""
ver="$(nvm version default 2>/dev/null || true)"
if [ -n "$ver" ] && [ "$ver" != "N/A" ]; then
  current_default="$(echo "$ver" | tr -d 'v' | cut -d. -f1)"
fi

# Determine default node version to offer
NODE_DEFAULT="24"
if [ -n "${current_default:-}" ]; then
  NODE_DEFAULT="$current_default"
fi

CHOSEN_VERSION=""
if [ -t 0 ]; then
  while :; do
    printf '\n'
    log "Node.js Version Selection"
    echo "Please choose the default Node.js major version to install/update:"
    echo "  - 24 (Recommended LTS)"
    echo "  - 25"
    echo "  - 26"
    echo "  (or enter any other valid major version number)"
    printf 'Enter version [default %s]: ' "$NODE_DEFAULT"
    read -r ans
    ans="${ans:-$NODE_DEFAULT}"

    case "$ans" in
      *[!0-9]*)
        warn "Invalid version number: '$ans'. Please enter a valid positive integer."
        ;;
      "")
        warn "Version cannot be empty."
        ;;
      *)
        if [ "$ans" -gt 0 ] 2>/dev/null; then
          CHOSEN_VERSION="$ans"
          break
        else
          warn "Invalid version number: '$ans'. Please enter a valid positive integer."
        fi
        ;;
    esac
  done
else
  # Non-interactive fallback
  CHOSEN_VERSION="$NODE_DEFAULT"
fi

# 2. Node install/update
log "node: installing/updating Node.js version $CHOSEN_VERSION"
nvm install "$CHOSEN_VERSION"
nvm alias default "$CHOSEN_VERSION" >/dev/null
nvm use "$CHOSEN_VERSION" >/dev/null

# 3. npm itself
npm install -g npm@latest >/dev/null 2>&1 || warn "node: npm self-update skipped"

ok "node ready: $(node -v) / npm $(npm -v)"
