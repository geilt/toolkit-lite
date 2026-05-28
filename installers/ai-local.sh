#!/usr/bin/env bash
# ai-local — local inference toolchain. Install/update, idempotent.
#
#   Ollama          local LLM server (API on :11434). Started + enabled at boot.
#   Hugging Face CLI `hf` — download models/datasets from huggingface.co.
#   MLX + mlx-lm    Apple's array framework + LLM tooling. Apple Silicon ONLY —
#                   skipped on Intel Macs and Linux. Runs an OpenAI-compatible
#                   server (mlx_lm.server) as a LaunchAgent on :11435.
#
# Notes:
#   · Ollama: macOS via Homebrew + `brew services` (auto-start); Linux via the
#     official install script (sets up a systemd service).
#   · MLX wheels lag the newest Python, so the venv is pinned to python@3.12.
#   · No models are pre-pulled — that's left to you (`ollama pull <model>`,
#     `hf download <repo>`). Both servers load models on demand.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

MLX_VENV="$HOME/.local/mlx"
MLX_PORT="${MLX_PORT:-11435}"
MLX_LABEL="toolkit-lite.mlx-server"
MLX_PLIST="$HOME/Library/LaunchAgents/$MLX_LABEL.plist"
LOG_DIR="$HOME/Library/Logs/toolkit-lite"

# ── Ollama ────────────────────────────────────────────────────────────────
install_ollama() {
  if [ "$(os)" = "macos" ]; then
    ensure_brew_on_path || { warn "ai-local: brew missing; skipping ollama"; return 1; }
    if brew list --formula --versions ollama >/dev/null 2>&1; then
      log "ollama: present — updating"; brew upgrade ollama 2>/dev/null || true
    else
      log "ollama: installing"; brew install ollama || { warn "ollama: install failed"; return 1; }
    fi
    # Start now + at login. `brew services` runs it as a user agent (no sudo;
    # :11434 is unprivileged).
    if brew services list 2>/dev/null | grep -qE '^ollama[[:space:]]+started'; then
      ok "ollama: service already running"
    else
      # restart (not start) clears a stopped *or* errored service in one shot.
      brew services restart ollama >/dev/null 2>&1 && ok "ollama: service started (auto-starts at login)" \
        || warn "ollama: couldn't start service (try: brew services restart ollama)"
    fi
  else
    if command -v ollama >/dev/null 2>&1; then
      ok "ollama: present ($(ollama --version 2>/dev/null | head -1))"
    else
      log "ollama: installing via official script (sets up a systemd service)"
      curl -fsSL https://ollama.com/install.sh | sh || { warn "ollama: install failed"; return 1; }
    fi
  fi
  command -v ollama >/dev/null 2>&1 && ok "ollama ready: $(ollama --version 2>/dev/null | head -1 || echo installed)"
}

# ── Hugging Face CLI (`hf`) ─────────────────────────────────────────────────
install_hf() {
  if [ "$(os)" = "macos" ]; then
    ensure_brew_on_path || { warn "ai-local: brew missing; skipping hf"; return 1; }
    if brew list --formula --versions hf >/dev/null 2>&1; then
      log "hf: present — updating"; brew upgrade hf 2>/dev/null || true
    else
      log "hf: installing Hugging Face CLI"; brew install hf || { warn "hf: install failed"; return 1; }
    fi
  else
    if command -v pipx >/dev/null 2>&1; then
      pipx install "huggingface_hub[cli]" 2>/dev/null || pipx upgrade huggingface_hub 2>/dev/null || true
    elif command -v pip3 >/dev/null 2>&1; then
      pip3 install --user -U "huggingface_hub[cli]" || warn "hf: pip install failed (try pipx)"
    else
      warn "hf: no pip/pipx found — install python3-pip then 'pip install huggingface_hub[cli]'"
      return 1
    fi
  fi
  command -v hf >/dev/null 2>&1 && ok "hf ready: $(hf version 2>/dev/null || echo installed)" \
    || command -v huggingface-cli >/dev/null 2>&1 && ok "hf ready (huggingface-cli)" \
    || log "hf: open a new shell so the CLI lands on PATH"
}

# ── MLX (Apple Silicon only) ────────────────────────────────────────────────
install_mlx() {
  if [ "$(os)" != "macos" ] || [ "$(uname -m)" != "arm64" ]; then
    log "mlx: Apple Silicon only — skipping on $(os)/$(uname -m)"
    return 0
  fi
  ensure_brew_on_path || { warn "ai-local: brew missing; skipping mlx"; return 1; }

  # MLX wheels track recent-but-not-bleeding-edge Python; pin to 3.12.
  if ! brew list --formula --versions python@3.12 >/dev/null 2>&1; then
    log "mlx: installing python@3.12 (for the MLX venv)"
    brew install python@3.12 || { warn "mlx: python@3.12 install failed"; return 1; }
  fi
  local pybin; pybin="$(brew --prefix python@3.12 2>/dev/null)/bin/python3.12"
  [ -x "$pybin" ] || { warn "mlx: python3.12 not found at $pybin"; return 1; }

  if [ ! -x "$MLX_VENV/bin/python" ]; then
    log "mlx: creating venv at $MLX_VENV (python 3.12)"
    "$pybin" -m venv "$MLX_VENV" || { warn "mlx: venv creation failed"; return 1; }
  fi
  log "mlx: installing/updating mlx + mlx-lm into the venv"
  "$MLX_VENV/bin/python" -m pip install -q -U pip >/dev/null 2>&1 || true
  "$MLX_VENV/bin/python" -m pip install -q -U mlx mlx-lm || { warn "mlx: pip install failed"; return 1; }

  local server="$MLX_VENV/bin/mlx_lm.server"
  [ -x "$server" ] || { warn "mlx: mlx_lm.server not found after install"; return 1; }

  # LaunchAgent: run the server (loads models on demand per request, so no
  # model needs to be chosen up front). Lives in ~/.local (not iCloud), so the
  # agent can exec it without sandbox issues.
  mkdir -p "$LOG_DIR" "$HOME/Library/LaunchAgents"
  cat > "$MLX_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$MLX_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$server</string>
    <string>--host</string><string>127.0.0.1</string>
    <string>--port</string><string>$MLX_PORT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>
  <dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$LOG_DIR/mlx-server.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/mlx-server.log</string>
</dict>
</plist>
PLIST

  launchctl bootout "gui/$(id -u)" "$MLX_PLIST" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$MLX_PLIST" 2>/dev/null; then
    ok "mlx: mlx_lm.server running on 127.0.0.1:$MLX_PORT (label $MLX_LABEL)"
  else
    warn "mlx: couldn't load LaunchAgent (load manually: launchctl bootstrap gui/$(id -u) $MLX_PLIST)"
  fi
}

log "ai-local: Ollama + Hugging Face CLI + MLX"
install_ollama || true
install_hf || true
install_mlx || true
ok "ai-local: done"
