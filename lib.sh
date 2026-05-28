#!/usr/bin/env bash
# lib.sh — shared helpers for toolkit-light.
#
# Generic, portable (macOS + common Linux). No personal config, no secrets.
# Sourced by install.sh and every installers/*.sh.

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  _C_CYAN="$(tput setaf 6 2>/dev/null || true)"
  _C_GREEN="$(tput setaf 2 2>/dev/null || true)"
  _C_YELLOW="$(tput setaf 3 2>/dev/null || true)"
  _C_RED="$(tput setaf 1 2>/dev/null || true)"
  _C_BOLD="$(tput bold 2>/dev/null || true)"
  _C_RESET="$(tput sgr0 2>/dev/null || true)"
else
  _C_CYAN=""; _C_GREEN=""; _C_YELLOW=""; _C_RED=""; _C_BOLD=""; _C_RESET=""
fi

log()  { printf '%s==>%s %s\n'  "$_C_CYAN$_C_BOLD" "$_C_RESET" "$*"; }
ok()   { printf '  %sok%s %s\n' "$_C_GREEN" "$_C_RESET" "$*"; }
warn() { printf '  %s!!%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
die()  { printf '  %sxx%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)  echo linux ;;
    *)      echo unknown ;;
  esac
}

# Linux distro family for package manager selection.
linux_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1;   then echo dnf
  elif command -v yum >/dev/null 2>&1;   then echo yum
  else echo unknown
  fi
}

# ---------------------------------------------------------------------------
# Homebrew (macOS). Sources brew env if installed but not on PATH.
# ---------------------------------------------------------------------------
ensure_brew_on_path() {
  command -v brew >/dev/null 2>&1 && return 0
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { eval "$("$b" shellenv)"; return 0; }
  done
  return 1
}

install_homebrew_if_missing() {
  [ "$(os)" = "macos" ] || return 0
  ensure_brew_on_path && { log "Homebrew present: $(command -v brew)"; return 0; }
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew install failed"
  ensure_brew_on_path || die "Homebrew installed but not on PATH"
  ok "Homebrew installed: $(command -v brew)"
}

# ---------------------------------------------------------------------------
# pkg_install <pkg> — cross-platform package install (idempotent).
# ---------------------------------------------------------------------------
pkg_install() {
  local pkg="$1"
  if [ "$(os)" = "macos" ]; then
    ensure_brew_on_path || { warn "brew missing; cannot install $pkg"; return 1; }
    brew list --formula --versions "$pkg" >/dev/null 2>&1 && return 0
    log "brew install $pkg"; brew install "$pkg"
  else
    case "$(linux_pkg_mgr)" in
      apt) sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
      dnf) sudo dnf install -y "$pkg" ;;
      yum) sudo yum install -y "$pkg" ;;
      *)   warn "no known package manager; install $pkg manually"; return 1 ;;
    esac
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# Resolve this repo's root from lib.sh's location.
TOOLKIT_LIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TOOLKIT_LIGHT_ROOT
