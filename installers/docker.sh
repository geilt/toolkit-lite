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
    # Docker Desktop (GUI). Detection priority:
    #   1. brew-managed cask          → upgrade it
    #   2. Docker.app already present  → installed outside brew (e.g. a web
    #      download); leave it ALONE — don't reinstall over a working app
    #   3. neither                     → install the cask
    if brew list --cask docker >/dev/null 2>&1; then
      log "docker: Docker Desktop present (brew-managed) — updating"
      brew upgrade --cask docker 2>/dev/null || true
      ok "docker: Docker Desktop ready — launch Docker.app once to start the engine"
    elif [ -d "/Applications/Docker.app" ] || [ -d "$HOME/Applications/Docker.app" ]; then
      ok "docker: Docker Desktop already installed (outside brew) — skipping install"
      log "docker: to let brew manage its updates instead, run: brew install --cask docker --adopt"
    else
      log "docker: installing Docker Desktop (cask)"
      brew install --cask docker || { warn "docker: cask install failed"; exit 1; }
      ok "docker: Docker Desktop ready — launch Docker.app once to start the engine"
    fi
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
# --- Compose v2 ---------------------------------------------------------------
# Make `docker compose` (and `docker-compose`) usable. Docker Desktop bundles
# the plugin but only wires it up after its first launch; Colima and CLI-only
# setups need the Homebrew formula. On macOS we also symlink the formula into
# ~/.docker/cli-plugins so the `docker compose` subcommand works even before
# Docker.app has ever been opened.
link_compose_plugin() {   # macOS: expose the brew docker-compose as a CLI plugin
  [ "$(os)" = "macos" ] || return 0
  ensure_brew_on_path || return 0
  local src; src="$(brew --prefix 2>/dev/null)/opt/docker-compose/bin/docker-compose"
  [ -x "$src" ] || return 0
  mkdir -p "$HOME/.docker/cli-plugins"
  ln -sfn "$src" "$HOME/.docker/cli-plugins/docker-compose" 2>/dev/null || true
}

if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
  if [ "$(os)" = "macos" ] && ensure_brew_on_path; then
    log "compose: not found — installing the docker-compose formula"
    brew list docker-compose >/dev/null 2>&1 || brew install docker-compose \
      || warn "compose: brew install docker-compose failed"
  fi
fi
# Always wire the brew docker-compose (if present) as a CLI plugin so the
# `docker compose` subcommand works — covers Colima + never-launched Desktop.
[ "$(os)" = "macos" ] && link_compose_plugin

if docker compose version >/dev/null 2>&1; then
  ok "compose: $(docker compose version 2>/dev/null | head -1)"
elif command -v docker-compose >/dev/null 2>&1; then
  ok "compose (standalone): $(docker-compose --version 2>/dev/null)"
else
  log "compose: 'docker compose' will be available once the engine (Docker.app/colima) is running"
fi
