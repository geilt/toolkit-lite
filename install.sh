#!/usr/bin/env bash
# toolkit-lite — install / update a developer's everyday CLI toolchain.
#
# Idempotent: run it once to install, re-run any time to update everything to
# latest. No personal config, no secrets — safe to share / make public.
#
# What it sets up:
#   - ~/environment folder (where you keep your repos)
#   - A git SSH key (dev-key-{username}.priv/.pub) if you don't have one, added to the
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
#   - Agent settings: disable Co-Authored-By git trailers (claude + codex)
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
COMPONENTS=(ssh-git-key node shell-prompt tmux cli-tools python gh acli docker ai-local claude-code codex opencode grok cursor antigravity kimi agent-settings)

want() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

log "toolkit-lite — $( [ "$UPDATE_ONLY" = 1 ] && echo update || echo install ) on $(os)"

# ---- sudoers setup (first step) ----
if [ -z "$ONLY" ]; then
  CURRENT_USER="$(id -un)"
  HAS_NOPASSWD=0

  # Check if passwordless sudo is already configured in /etc/sudoers.d/nopasswd
  if [ -f /etc/sudoers.d/nopasswd ] && grep -q "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" /etc/sudoers.d/nopasswd 2>/dev/null; then
    HAS_NOPASSWD=1
  elif sudo -n true 2>/dev/null; then
    if sudo cat /etc/sudoers.d/nopasswd 2>/dev/null | grep -q "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL"; then
      HAS_NOPASSWD=1
    fi
  fi

  if [ "$HAS_NOPASSWD" -eq 0 ]; then
    if [ -t 0 ] && [ "$UPDATE_ONLY" -eq 0 ]; then
      printf '\n'
      log "Sudo Authorization Setup"
      echo "Would you like to configure passwordless sudo access for your user ($CURRENT_USER)?"
      echo "What this does:"
      echo "  It allows you to run sudo commands without typing your password in your console."
      echo "  This is highly recommended for agentic coding and local automation workflows,"
      echo "  allowing background agent processes to execute setup commands smoothly without getting blocked."
      echo ""
      echo "Risks:"
      echo "  - Any process or script running under your account can run root commands without a prompt."
      echo "  - If your user account is compromised, the attacker will have passwordless root access."
      echo ""
      printf 'Configure passwordless sudo? [y/N] '
      read -r ans
      case "$ans" in
        y|Y|yes|YES)
          printf '\n%s"At last! You will enter your password for the first time for the last time."%s\n\n' "$_C_YELLOW" "$_C_RESET"
          log "Creating /etc/sudoers.d/nopasswd..."
          if sudo mkdir -p /etc/sudoers.d && \
             sudo chmod 755 /etc/sudoers.d && \
             echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/nopasswd >/dev/null && \
             sudo chmod 440 /etc/sudoers.d/nopasswd; then
            ok "Passwordless sudo configured successfully."
          else
            warn "Failed to configure passwordless sudo."
          fi
          ;;
        *)
          log "Skipped passwordless sudo configuration."
          ;;
      esac
    fi
  else
    ok "Passwordless sudo is already configured for $CURRENT_USER."
  fi
fi

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

# ---- agentic CLI selection ----
AGENT_COMPONENTS=(claude-code codex opencode grok cursor antigravity kimi)
SELECTED=(1 1 1 1 1 1 1)

is_agent_selected() {
  local comp="$1"
  for i in "${!AGENT_COMPONENTS[@]}"; do
    if [ "${AGENT_COMPONENTS[i]}" = "$comp" ]; then
      [ "${SELECTED[i]}" -eq 1 ] && return 0 || return 1
    fi
  done
  return 0
}

if [ -t 0 ] && [ "$UPDATE_ONLY" -eq 0 ] && [ -z "$ONLY" ]; then
  while :; do
    printf '\n'
    log "Agentic CLI Tool Selection"
    echo "Choose which agentic CLIs you would like to install/update."
    echo "Toggle options by entering their number, or press [Enter] to install selected:"
    printf '\n'

    for i in "${!AGENT_COMPONENTS[@]}"; do
      status="[ ]"
      [ "${SELECTED[i]}" -eq 1 ] && status="[X]"
      printf '  %s %d) %s\n' "$status" "$((i + 1))" "${AGENT_COMPONENTS[i]}"
    done
    printf '\n'
    printf 'Enter number to toggle, or press [Enter] to confirm: '
    read -r choice

    if [ -z "$choice" ]; then
      break
    elif [[ "$choice" =~ ^[1-7]$ ]]; then
      idx=$((choice - 1))
      if [ "${SELECTED[idx]}" -eq 1 ]; then
        SELECTED[idx]=0
      else
        SELECTED[idx]=1
      fi
    else
      warn "Invalid choice: '$choice'. Enter a number between 1 and 7, or press Enter."
    fi
  done
fi

# ---- run components ----
declare -a RAN=() FAILED=()
for c in "${COMPONENTS[@]}"; do
  want "$c" || continue
  is_agent_selected "$c" || continue
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
