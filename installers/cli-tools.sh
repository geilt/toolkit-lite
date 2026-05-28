#!/usr/bin/env bash
# cli-tools — everyday CLI utilities that speed up AI-assisted dev + shell work.
# Install/update, idempotent.
#
#   ripgrep (rg)  fast recursive search — agentic CLIs (claude/codex/…) prefer it
#   fd            fast, friendly 'find'
#   fzf           fuzzy finder (history/files)
#   bat           'cat' with syntax highlighting
#   wget          classic downloader (some installers expect it)
#   gnupg (gpg)   signing / commit verification
#
# Package names differ across managers; mapped in pkg_for().
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Logical tool list (brew formula names; remapped for Linux managers below).
TOOLS="ripgrep fd fzf bat wget gnupg"

# Map a logical tool name → the package name for the active package manager.
pkg_for() {
  local tool="$1" mgr
  if [ "$(os)" = "macos" ]; then mgr=brew; else mgr="$(linux_pkg_mgr)"; fi
  case "$tool:$mgr" in
    fd:apt)     echo fd-find ;;   # binary installs as 'fdfind' on Debian/Ubuntu
    fd:dnf)     echo fd-find ;;
    fd:yum)     echo fd-find ;;
    gnupg:dnf)  echo gnupg2 ;;
    gnupg:yum)  echo gnupg2 ;;
    *)          echo "$tool" ;;
  esac
}

for t in $TOOLS; do
  pkg="$(pkg_for "$t")"
  if [ "$(os)" = "macos" ]; then
    if ensure_brew_on_path && brew list --formula --versions "$pkg" >/dev/null 2>&1; then
      brew upgrade "$pkg" 2>/dev/null || true
    else
      pkg_install "$pkg" || warn "cli-tools: $pkg install failed (continuing)"
    fi
  else
    pkg_install "$pkg" || warn "cli-tools: $pkg install failed (continuing)"
  fi
done

# Cosmetic summary of what landed on PATH (binary names, not package names).
present=""
for c in rg fd fdfind fzf bat batcat wget gpg; do
  command -v "$c" >/dev/null 2>&1 && present="$present $c"
done
ok "cli-tools ready:${present:- (none on PATH yet — open a new shell)}"
