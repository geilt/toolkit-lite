#!/usr/bin/env bash
# ssh-git-key — generate a dedicated SSH key for git hosting (GitHub, Bitbucket,
# GitLab, …) if one doesn't exist, install it, add it to the ssh-agent, wire
# ~/.ssh/config for the common git hosts, and tell the user which file to upload.
#
# Standalone by design: the key lives directly in ~/.ssh (NOT a shared/iCloud
# folder — that's the heavier macos-toolkit's job, not this one).
#
# Key named with .priv / .pub extensions (host-agnostic — one key, upload the
# public half to whichever git host(s) you use):
#   ~/.ssh/dev-key.priv   (private — chmod 600, added to agent)
#   ~/.ssh/dev-key.pub    (public  — chmod 644, upload THIS)
#
# Only prompts if the key doesn't already exist (file check first).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SSH_DIR="$HOME/.ssh"
GIT_HOSTS="github.com bitbucket.org"   # hosts to wire into ~/.ssh/config

STATE_DIR="$HOME/.config/toolkit-lite"
pref_name=""
[ -f "$STATE_DIR/preferred-name" ] && pref_name="$(head -1 "$STATE_DIR/preferred-name" 2>/dev/null)"
chosen_user="${pref_name:-$(id -un)}"

PRIV=""
PUB=""

# Check for legacy dev-key.priv or any dev-key-*.priv
if [ -f "$SSH_DIR/dev-key.priv" ]; then
  PRIV="$SSH_DIR/dev-key.priv"
  PUB="$SSH_DIR/dev-key.pub"
else
  # Check for any existing dev-key-*.priv files
  for f in "$SSH_DIR"/dev-key-*.priv; do
    if [ -f "$f" ]; then
      PRIV="$f"
      PUB="${f%.priv}.pub"
      break
    fi
  done
fi

# If no existing key is found, define the path using the chosen username suffix
if [ -z "$PRIV" ]; then
  PRIV="$SSH_DIR/dev-key-${chosen_user}.priv"
  PUB="$SSH_DIR/dev-key-${chosen_user}.pub"
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

open_url() {
  local url="$1"
  if [ "$(os)" = "macos" ]; then
    open "$url" 2>/dev/null || true
  else
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$url" 2>/dev/null || true
    elif command -v sensible-browser >/dev/null 2>&1; then
      sensible-browser "$url" 2>/dev/null || true
    else
      python3 -m webbrowser "$url" >/dev/null 2>&1 || true
    fi
  fi
}

copy_to_clipboard() {
  local file="$1"
  if [ "$(os)" = "macos" ]; then
    if command -v pbcopy >/dev/null 2>&1; then
      pbcopy < "$file" && return 0
    fi
  else
    if command -v xclip >/dev/null 2>&1; then
      xclip -sel clip < "$file" && return 0
    elif command -v xsel >/dev/null 2>&1; then
      xsel -ib < "$file" && return 0
    elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
      wl-copy < "$file" && return 0
    fi
  fi
  return 1
}

add_to_agent() {
  if [ "$(os)" = "macos" ]; then
    ssh-add --apple-use-keychain "$PRIV" 2>/dev/null \
      || ssh-add "$PRIV" 2>/dev/null \
      || warn "ssh: couldn't add key to agent (add manually: ssh-add $PRIV)"
  else
    ssh-add "$PRIV" 2>/dev/null \
      || { eval "$(ssh-agent -s)" >/dev/null 2>&1; ssh-add "$PRIV" 2>/dev/null; } \
      || warn "ssh: couldn't add key to agent (add manually: ssh-add $PRIV)"
  fi
}

# True if the `Host <host>` block in $cfg already references our dev-key.
host_block_has_key() {
  local host="$1" cfg="$2"
  [ -f "$cfg" ] || return 1
  awk -v host="$host" '
    tolower($1)=="host" { inblk=0; for (i=2;i<=NF;i++) if ($i==host) inblk=1; next }
    inblk { print }
  ' "$cfg" | grep -qiE 'IdentityFile[[:space:]]+.*dev-key.*\.priv'
}

# True if a `Host <host>` block exists at all.
host_block_exists() {
  local host="$1" cfg="$2"
  [ -f "$cfg" ] || return 1
  awk -v host="$host" '
    tolower($1)=="host" { for (i=2;i<=NF;i++) if ($i==host) { found=1 } }
    END { exit(found?0:1) }
  ' "$cfg"
}

# Ensure ~/.ssh/config sets the dev-key as the IdentityFile for a git host.
# The friend almost certainly has no prepared config, so we do a real file edit:
#   · no block for the host        → append a full block
#   · block exists, our key set     → leave it (already wired)
#   · block exists, our key missing → back up, then inject IdentityFile into it
wire_host() {
  local host="$1" cfg="$SSH_DIR/config"
  [ -f "$cfg" ] || { : > "$cfg"; chmod 600 "$cfg"; }

  if ! host_block_exists "$host" "$cfg"; then
    {
      printf '\nHost %s\n' "$host"
      printf '  HostName %s\n' "$host"
      printf '  User git\n'
      printf '  IdentityFile %s\n' "$PRIV"
      printf '  AddKeysToAgent yes\n'
      [ "$(os)" = "macos" ] && printf '  UseKeychain yes\n'
    } >> "$cfg"
    chmod 600 "$cfg"
    ok "ssh: added a $host block to $cfg (uses dev-key)"
    return 0
  fi

  if host_block_has_key "$host" "$cfg"; then
    ok "ssh: $host block already points at dev-key — leaving it"
    return 0
  fi

  # Block exists but lacks our key — inject IdentityFile right after the Host line.
  local bak="$cfg.bak.$(date +%Y%m%d-%H%M%S)" tmp="$cfg.tmp.$$"
  cp -p "$cfg" "$bak"
  awk -v host="$host" -v key="$PRIV" '
    { print }
    !done && tolower($1)=="host" {
      for (i=2;i<=NF;i++) if ($i==host) { print "  IdentityFile " key; done=1; break }
    }
  ' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  chmod 600 "$cfg"
  ok "ssh: set dev-key as IdentityFile in the existing $host block (backup: $bak)"
}

# ── Git commit attribution config ──
HAS_GIT_CONFIG=1
if [ -z "$(git config --global user.name 2>/dev/null || true)" ] || [ -z "$(git config --global user.email 2>/dev/null || true)" ]; then
  HAS_GIT_CONFIG=0
fi

# Prompt if git config is missing, or if we are in an interactive key creation flow
if [ -t 0 ] && { [ "$HAS_GIT_CONFIG" -eq 0 ] || [ ! -f "$PRIV" ]; }; then
  if [ "$HAS_GIT_CONFIG" -eq 1 ]; then
    printf '\n'
    log "Git Commit Attribution"
    echo "Git is already configured: $(git config --global user.name) <$(git config --global user.email)>"
    printf 'Press [Enter] to accept, or type "change" to reconfigure [accept]: '
    read -r confirm
    if [ "$confirm" = "change" ]; then
      HAS_GIT_CONFIG=0
    fi
  fi

  if [ "$HAS_GIT_CONFIG" -eq 0 ]; then
    STATE_DIR="$HOME/.config/toolkit-lite"
    pref_name=""
    [ -f "$STATE_DIR/preferred-name" ] && pref_name="$(head -1 "$STATE_DIR/preferred-name" 2>/dev/null)"
    
    default_git_name="$(git config --global user.name 2>/dev/null || echo "${pref_name:-$(id -un)}")"
    default_git_email="$(git config --global user.email 2>/dev/null || echo "$(id -un)@$(hostname -s 2>/dev/null || echo host).local")"

    printf '\n'
    log "Git Commit Attribution"
    echo "Configure the name and email that will be stamped on your git commits."
    
    printf 'Git user name [%s]: ' "$default_git_name"
    read -r git_name
    chosen_git_name="${git_name:-$default_git_name}"

    printf 'Git email address [%s]: ' "$default_git_email"
    read -r git_email
    chosen_git_email="${git_email:-$default_git_email}"

    log "Setting global git config..."
    git config --global user.name "$chosen_git_name"
    git config --global user.email "$chosen_git_email"
    ok "Git configured: $chosen_git_name <$chosen_git_email>"
  fi
fi

# ── Already exists → keep the key, but still ensure the agent + ssh config are
#    wired (re-runs must converge: a friend may have a key but no config yet) ──
if [ -f "$PRIV" ]; then
  ok "ssh: dev-key already exists at $PRIV — leaving the key as-is"
  add_to_agent
  for h in $GIT_HOSTS; do wire_host "$h"; done
  log "Reminder: the file to upload to your git host(s) is the PUBLIC key → $PUB"
  exit 0
fi

# ── Doesn't exist → ask (skip cleanly if non-interactive) ──
if [ ! -t 0 ]; then
  log "ssh: no git key found and no terminal to prompt — skipping (run interactively to create one)"
  exit 0
fi

printf 'No git SSH key found. Generate one now (for GitHub/Bitbucket/etc)? [Y/n] '
read -r ans
case "${ans:-Y}" in
  n|N|no|NO) log "ssh: skipped key generation"; exit 0 ;;
esac

default_comment="$(id -un)@$(hostname -s 2>/dev/null || echo host)-dev-key"
printf 'Label/email to tag the key with [%s]: ' "$default_comment"
read -r raw_comment
comment="${raw_comment:-$default_comment}"

log "ssh: generating ed25519 key (no passphrase; stored in agent/keychain)"
ssh-keygen -t ed25519 -f "$PRIV" -C "$comment" -N ""

# ssh-keygen writes <name> and <name>.pub; rename the public half to dev-key.pub
mv "$PRIV.pub" "$PUB"
chmod 600 "$PRIV"
chmod 644 "$PUB"

add_to_agent

# Wire the common git hosts (each idempotent).
for h in $GIT_HOSTS; do wire_host "$h"; done

# ── Tell the user what to do ──
printf '\n'
ok "ssh: dev-key created"
log "Upload the PUBLIC key below to whichever git host(s) you use:"
log "  GitHub    -> Settings -> SSH and GPG keys -> New SSH key"
log "  Bitbucket -> Personal settings -> SSH keys -> Add key"
printf '\n  file to upload: %s\n\n' "$PUB"
sed 's/^/    /' "$PUB"
printf '\n'

if copy_to_clipboard "$PUB"; then
  ok "ssh: public key copied to your clipboard — just paste it in!"
else
  warn "ssh: could not copy public key to clipboard automatically"
fi

if [ -t 0 ]; then
  printf '\n'
  log "Browser Integration"
  echo "Would you like us to open the browser to the SSH settings page for you?"
  echo "  1) Open GitHub settings (to add key directly)"
  echo "  2) Open Bitbucket settings"
  echo "  3) Open both"
  echo "  4) Skip/No"
  printf 'Enter choice [1-4, default 4]: '
  read -r browser_choice
  case "$browser_choice" in
    1)
      log "Opening GitHub settings..."
      open_url "https://github.com/settings/ssh/new"
      ;;
    2)
      log "Opening Bitbucket settings..."
      open_url "https://bitbucket.org/account/settings/ssh-keys/"
      ;;
    3)
      log "Opening GitHub and Bitbucket settings..."
      open_url "https://github.com/settings/ssh/new"
      open_url "https://bitbucket.org/account/settings/ssh-keys/"
      ;;
    *)
      log "Skipped opening browser."
      ;;
  esac
fi

log "After uploading, test with:  ssh -T git@github.com   (or git@bitbucket.org)"
