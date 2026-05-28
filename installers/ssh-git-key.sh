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
PRIV="$SSH_DIR/dev-key.priv"
PUB="$SSH_DIR/dev-key.pub"
GIT_HOSTS="github.com bitbucket.org"   # hosts to wire into ~/.ssh/config

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

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

# Append a Host block for a git host to ~/.ssh/config, only if one isn't there.
wire_host() {
  local host="$1" cfg="$SSH_DIR/config"
  if [ -f "$cfg" ] && grep -qiE "^[[:space:]]*Host[[:space:]]+${host//./\\.}([[:space:]]|\$)" "$cfg"; then
    log "ssh: $cfg already has a $host block — not modifying it"
    return 0
  fi
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
}

# ── Already exists → leave it alone (don't re-prompt, don't overwrite) ──
if [ -f "$PRIV" ]; then
  ok "ssh: dev-key already exists at $PRIV — leaving it as-is"
  add_to_agent
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
if [ "$(os)" = "macos" ] && command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$PUB" && ok "ssh: public key copied to your clipboard — just paste it in"
fi
log "After uploading, test with:  ssh -T git@github.com   (or git@bitbucket.org)"
