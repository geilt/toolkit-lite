#!/usr/bin/env bash
# toolkit-lite — install / update a developer's everyday CLI toolchain.
#
# Idempotent: run it once to install, re-run any time to update everything to
# latest. No personal config, no secrets — safe to share / make public.
#
# What it sets up:
#   - ~/environment folder (where you keep your repos)
#   - A git SSH key (dev-key.priv/.pub) if you don't have one, added to the
#     agent + wired into ~/.ssh/config for GitHub + Bitbucket (tells you which
#     file to upload)
#   - Homebrew (macOS, if missing)
#   - jq, tmux
#   - Colored shell prompt (username@hostname, green/blue) for zsh + bash
#   - CLI utilities: ripgrep, fd, fzf, bat, wget, gnupg
#   - Python: uv + CPython 3.11/3.12/3.13 (3.12 default) + ruff/ipython/httpie/pre-commit
#   - nvm + Node.js LTS
#   - tmux config (vi keys, mouse, status bar — prompts once for a name)
#   - Dev CLIs: GitHub CLI (gh), Atlassian CLI (acli), Docker + Compose
#   - Local inference: Ollama (service), Hugging Face CLI, MLX (Apple Silicon)
#   - Agentic coding CLIs: claude-code, codex, opencode, grok, cursor,
#     antigravity, kimi
#
# Usage:
#   ./install.sh                  # interactive install/update (prompts for name first run)
#   ./install.sh --update         # same, but never prompt (reuse existing tmux name)
#   ./install.sh --only tmux,node # run just the named components
#   TOOLKIT_LITE_USERNAME=sam ./install.sh    # preset the tmux name, no prompt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/lib.sh"

# ---- args ----
UPDATE_ONLY=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --update) UPDATE_ONLY=1; export TOOLKIT_LITE_USERNAME="${TOOLKIT_LITE_USERNAME:-${TOOLKIT_LIGHT_USERNAME:-}}" ;;
    --only)   ONLY="$2"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) warn "unknown arg: $1" ;;
  esac
  shift
done

# Components in dependency order. ssh key first; node before codex/opencode
# (they need npm); then dev CLIs; then the agentic CLIs.
COMPONENTS=(ssh-git-key node shell-prompt tmux cli-tools python gh acli docker ai-local claude-code codex opencode grok cursor antigravity kimi)

want() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

log "toolkit-lite — $( [ "$UPDATE_ONLY" = 1 ] && echo update || echo install ) on $(os)"

# ---- prerequisites ----
# ~/environment — where repos live (this toolkit included). Create if missing.
if [ ! -d "$HOME/environment" ]; then
  log "creating ~/environment"
  mkdir -p "$HOME/environment" && ok "created $HOME/environment"
else
  ok "~/environment exists"
fi

install_homebrew_if_missing
if want jq; then pkg_install jq || warn "jq install skipped"; fi

# ---- run components ----
declare -a RAN=() FAILED=()
for c in "${COMPONENTS[@]}"; do
  want "$c" || continue
  printf '\n'
  if bash "$ROOT/installers/$c.sh"; then
    RAN+=("$c")
  else
    FAILED+=("$c")
    warn "$c failed (continuing)"
  fi
done

# ---- summary ----
printf '\n'
log "summary"
printf '  installed/updated: %s\n' "${RAN[*]:-none}"
[ "${#FAILED[@]}" -gt 0 ] && printf '  %sfailed:%s            %s\n' "$_C_YELLOW" "$_C_RESET" "${FAILED[*]}"
printf '\n'
ok "done. Open a new shell (or 'exec \$SHELL -l') so PATH + nvm load."
[ "${#FAILED[@]}" -eq 0 ] || exit 1
