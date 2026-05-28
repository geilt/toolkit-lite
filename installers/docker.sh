#!/usr/bin/env bash
# docker — Docker + Docker Compose. Install/update.
#
#   macOS (default):  Docker Desktop (cask). Best UX on an interactive Mac.
#   macOS (headless): set DOCKER_RUNTIME=colima to install Colima + docker CLI
#                     + docker-compose instead — runs without a GUI, SSH-friendly.
#   Linux:            Docker Engine via the official get.docker.com script
#                     (includes the compose v2 plugin).
#
# Compose v2 ships as the `docker compose` subcommand (bundled with Desktop and
# the Linux engine); the Colima path also installs the standalone docker-compose.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

RUNTIME="${DOCKER_RUNTIME:-desktop}"   # desktop | colima

if [ "$(os)" = "macos" ]; then
  ensure_brew_on_path || { warn "docker: brew missing"; exit 1; }

  if [ "$RUNTIME" = "colima" ]; then
    log "docker: Colima runtime + docker CLI + compose (headless mode)"
    for f in colima docker docker-compose; do
      if brew list "$f" >/dev/null 2>&1; then brew upgrade "$f" 2>/dev/null || true
      else brew install "$f" || warn "docker: brew install $f failed"; fi
    done
    ok "docker: Colima installed — start the VM with: colima start"
  else
    if brew list --cask docker >/dev/null 2>&1; then
      log "docker: Docker Desktop present (brew-managed) — updating"
      brew upgrade --cask docker 2>/dev/null || true
    elif [ -d "/Applications/Docker.app" ]; then
      # Docker.app exists but wasn't installed by brew → a plain `brew install
      # --cask docker` errors ("already an App at ..."). Try to adopt it into
      # brew; if that's unsupported, leave the working install untouched.
      log "docker: Docker.app already installed (not via brew) — adopting into brew"
      brew install --cask docker --adopt 2>/dev/null \
        || ok "docker: existing Docker.app left as-is (brew couldn't adopt it; no action needed)"
    else
      log "docker: installing Docker Desktop (cask)"
      brew install --cask docker || { warn "docker: cask install failed"; exit 1; }
    fi
    ok "docker: Docker Desktop ready — launch Docker.app once to start the engine"
    log "docker: on a headless/remote box, re-run with DOCKER_RUNTIME=colima instead"
  fi
else
  if command -v docker >/dev/null 2>&1; then
    ok "docker: present ($(docker --version 2>/dev/null))"
  else
    log "docker: installing Docker Engine via get.docker.com"
    curl -fsSL https://get.docker.com | sh || { warn "docker: install failed"; exit 1; }
    command -v usermod >/dev/null 2>&1 && sudo usermod -aG docker "$(id -un)" 2>/dev/null || true
    log "docker: you may need to log out/in for docker group membership to take effect"
  fi
fi

command -v docker >/dev/null 2>&1 \
  && ok "docker CLI: $(docker --version 2>/dev/null || echo installed)" \
  || warn "docker: CLI not on PATH yet (Docker Desktop may need a first launch)"
if docker compose version >/dev/null 2>&1; then
  ok "compose: $(docker compose version 2>/dev/null | head -1)"
elif command -v docker-compose >/dev/null 2>&1; then
  ok "compose: $(docker-compose --version 2>/dev/null)"
else
  log "compose: available as 'docker compose' once the engine is running"
fi
