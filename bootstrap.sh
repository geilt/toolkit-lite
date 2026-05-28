#!/usr/bin/env bash
# bootstrap.sh — one-line remote installer for toolkit-lite.
#
# Run it straight from GitHub (recommended form keeps prompts interactive):
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)"
#
# …or with wget:
#
#   bash -c "$(wget -qO- https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)"
#
# It clones (or updates) the repo into ~/environment/toolkit-lite, then runs
# ./install.sh. Pass extra args through after a `--`, e.g. install just a couple
# of components:
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)" -- --only node,tmux
#
# Overridable via env: TOOLKIT_LITE_REPO (clone URL), TOOLKIT_LITE_DIR (target).
set -euo pipefail

REPO_URL="${TOOLKIT_LITE_REPO:-https://github.com/geilt/toolkit-lite.git}"
DEST="${TOOLKIT_LITE_DIR:-$HOME/environment/toolkit-lite}"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# 1. git is required to clone. On macOS, `git` triggers the Xcode Command Line
#    Tools install; on Linux, install via the system package manager.
if ! command -v git >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)
      say "git not found — triggering Xcode Command Line Tools install"
      xcode-select --install 2>/dev/null || true
      die "re-run this command once the Command Line Tools finish installing" ;;
    Linux)
      if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y git
      elif command -v dnf >/dev/null 2>&1;     then sudo dnf install -y git
      elif command -v yum >/dev/null 2>&1;     then sudo yum install -y git
      else die "no known package manager — install git, then re-run"; fi ;;
    *) die "unsupported OS — install git and clone $REPO_URL manually" ;;
  esac
fi

# 2. Clone fresh, or update an existing checkout. HTTPS so a brand-new machine
#    (no SSH key yet — the installer sets one up) can clone without auth.
mkdir -p "$(dirname "$DEST")"
if [ -d "$DEST/.git" ]; then
  say "updating existing checkout at $DEST"
  git -C "$DEST" pull --ff-only \
    || say "git pull skipped (local changes?) — continuing with the current checkout"
else
  say "cloning $REPO_URL → $DEST"
  git clone "$REPO_URL" "$DEST" || die "git clone failed"
fi

# 3. Hand off to the installer, passing through any extra args.
say "running installer"
cd "$DEST"
exec ./install.sh "$@"
