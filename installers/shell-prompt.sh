#!/usr/bin/env bash
# shell-prompt — offer a colored `username@hostname` shell prompt using the same
# green/blue scheme as the TLD Toolkit. Runs BEFORE the tmux step so the chosen
# name carries over as the tmux status-bar default.
#
#   green  = username@hostname     blue = working dir      (matches tldtoolkit)
#   inside tmux the host shows as `tmux` (like tldtoolkit)
#
# Only offers if no prompt is already set (never clobbers an existing PS1).
# Writes zsh syntax to ~/.zshrc and bash syntax to ~/.bashrc — on macOS both are
# configured/checked, on Linux at least ~/.bashrc. If you pick a hostname that
# differs from the machine's, it can also update the macOS local hostname
# (System Settings → Sharing).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

STATE_DIR="$HOME/.config/toolkit-lite"
STATE_FILE="$STATE_DIR/preferred-name"
ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"

def_user="$(id -un)"
if [ "$(os)" = "macos" ]; then
  def_host="$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo host)"
else
  def_host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"
fi

has_bash_prompt() { [ -f "$1" ] && grep -qE '^[[:space:]]*PS1=' "$1"; }
has_zsh_prompt()  { [ -f "$1" ] && grep -qE '^[[:space:]]*(PROMPT|PS1)=' "$1"; }

# Emit a prompt block (placeholders substituted) to stdout.
emit_bash_block() {   # $1=user $2=host
  cat <<'EOF' | sed -e "s/__TLUSER__/$1/g" -e "s/__TLHOST__/$2/g"

# >>> toolkit-lite prompt >>>
if [ -n "$TMUX" ]; then
  PS1='\[\e[32m\]__TLUSER__@tmux:\[\e[34m\]\w\[\e[0m\] $ '
else
  PS1='\[\e[32m\]__TLUSER__@__TLHOST__:\[\e[34m\]\w\[\e[0m\] $ '
fi
# <<< toolkit-lite prompt <<<
EOF
}
emit_zsh_block() {    # $1=user $2=host
  cat <<'EOF' | sed -e "s/__TLUSER__/$1/g" -e "s/__TLHOST__/$2/g"

# >>> toolkit-lite prompt >>>
if [ -n "$TMUX" ]; then
  PROMPT='%F{green}__TLUSER__@tmux:%F{blue}%~%f $ '
else
  PROMPT='%F{green}__TLUSER__@__TLHOST__:%F{blue}%~%f $ '
fi
# <<< toolkit-lite prompt <<<
EOF
}

# Decide which rc files still need a prompt.
want_zsh=0; want_bash=0
if [ "$(os)" = "macos" ] || command -v zsh >/dev/null 2>&1 || [ -f "$ZSHRC" ]; then
  has_zsh_prompt "$ZSHRC" || want_zsh=1
fi
has_bash_prompt "$BASHRC" || want_bash=1

if [ "$want_zsh" = 0 ] && [ "$want_bash" = 0 ]; then
  ok "shell-prompt: a prompt is already set in your shell rc file(s) — leaving it"
  mkdir -p "$STATE_DIR"; printf '%s\n' "$def_user" > "$STATE_FILE"
  exit 0
fi

if [ ! -t 0 ]; then
  log "shell-prompt: no terminal to prompt — skipping (run interactively to configure)"
  exit 0
fi

printf 'Set up a colored shell prompt (username@hostname, green/blue)? [Y/n] '
read -r ans
case "${ans:-Y}" in n|N|no|NO) log "shell-prompt: skipped"; exit 0 ;; esac

printf 'Username to show in the prompt (%s): ' "$def_user"
read -r in_user; chosen_user="${in_user:-$def_user}"

printf 'Hostname to show in the prompt (%s): ' "$def_host"
read -r in_host; chosen_host="${in_host:-$def_host}"

# macOS only: if the chosen hostname differs from the machine's, offer (required
# y/n) to change the actual local hostname (Sharing → "hostname.local").
if [ "$(os)" = "macos" ] && [ "$chosen_host" != "$def_host" ]; then
  clean_host="$(printf '%s' "$chosen_host" | tr ' ' '-' | tr -cd '[:alnum:]-')"
  while :; do
    printf "Also change this Mac's local hostname from '%s' to '%s' (System Settings → Sharing)? [y/n] " "$def_host" "$clean_host"
    read -r hn
    case "$hn" in
      y|Y|yes|YES)
        log "shell-prompt: setting local hostname to '$clean_host' (may prompt for your password)"
        sudo scutil --set HostName      "$clean_host"  2>/dev/null || warn "shell-prompt: failed to set HostName"
        sudo scutil --set LocalHostName "$clean_host"  2>/dev/null || warn "shell-prompt: failed to set LocalHostName"
        sudo scutil --set ComputerName  "$chosen_host" 2>/dev/null || warn "shell-prompt: failed to set ComputerName"
        chosen_host="$clean_host"
        ok "shell-prompt: local hostname is now '$clean_host' (${clean_host}.local)"
        break ;;
      n|N|no|NO)
        log "shell-prompt: leaving the system hostname; using '$chosen_host' in the prompt only"
        break ;;
      *) printf '  please answer y or n\n' ;;
    esac
  done
fi

if [ "$want_zsh" = 1 ]; then
  [ -f "$ZSHRC" ] || : > "$ZSHRC"
  emit_zsh_block "$chosen_user" "$chosen_host" >> "$ZSHRC"
  ok "shell-prompt: added zsh prompt to $ZSHRC"
fi
if [ "$want_bash" = 1 ]; then
  [ -f "$BASHRC" ] || : > "$BASHRC"
  emit_bash_block "$chosen_user" "$chosen_host" >> "$BASHRC"
  ok "shell-prompt: added bash prompt to $BASHRC"
fi

# Persist the chosen name so the tmux step defaults to it (Enter = use on both).
mkdir -p "$STATE_DIR"; printf '%s\n' "$chosen_user" > "$STATE_FILE"

ok "shell-prompt: done — open a new shell to see ${chosen_user}@${chosen_host}"
