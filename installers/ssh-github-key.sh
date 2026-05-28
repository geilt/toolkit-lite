#!/usr/bin/env bash
# ssh-github-key — generate a dedicated GitHub SSH key if one doesn't exist,
# install it, add it to the ssh-agent, wire ~/.ssh/config for github.com, and
# tell the user which file to upload to GitHub.
#
# Standalone by design: the key lives directly in ~/.ssh (NOT a shared/iCloud
# folder — that's the heavier macos-toolkit's job, not this one).
#
# Key is named with .priv / .pub extensions:
#   ~/.ssh/dev-key.priv   (private — chmod 600, added to agent)
#   ~/.ssh/dev-key.pub    (public  — chmod 644, upload THIS to GitHub)
#
# Only prompts if the key doesn't already exist (file check first).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SSH_DIR="$HOME/.ssh"
PRIV="$SSH_DIR/dev-key.priv"
PUB="$SSH_DIR/dev-key.pub"

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

# ── Already exists → leave it alone (don't re-prompt, don't overwrite) ──
if [ -f "$PRIV" ]; then
  ok "ssh: dev-key already exists at $PRIV — leaving it as-is"
  add_to_agent
  log "Reminder: the file to upload to GitHub is the PUBLIC key → $PUB"
  exit 0
fi

# ── Doesn't exist → ask (skip cleanly if non-interactive) ──
if [ ! -t 0 ]; then
  log "ssh: no GitHub key found and no terminal to prompt — skipping (run interactively to create one)"
  exit 0
fi

printf 'No GitHub SSH key found. Generate one now? [Y/n] '
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

# ── Wire ~/.ssh/config so github.com uses this key (only if no block exists) ──
CFG="$SSH_DIR/config"
if ! { [ -f "$CFG" ] && grep -qiE '^[[:space:]]*Host[[:space:]]+github\.com([[:space:]]|$)' "$CFG"; }; then
  {
    printf '\nHost github.com\n'
    printf '  HostName github.com\n'
    printf '  User git\n'
    printf '  IdentityFile %s\n' "$PRIV"
    printf '  AddKeysToAgent yes\n'
    [ "$(os)" = "macos" ] && printf '  UseKeychain yes\n'
  } >> "$CFG"
  chmod 600 "$CFG"
  ok "ssh: added a github.com block to $CFG (uses dev-key)"
else
  log "ssh: $CFG already has a github.com block — not modifying it"
fi

# ── Tell the user what to do ──
printf '\n'
ok "ssh: dev-key created"
log "Upload the PUBLIC key below to GitHub → Settings → SSH and GPG keys → New SSH key"
printf '\n  file to upload: %s\n\n' "$PUB"
sed 's/^/    /' "$PUB"
printf '\n'
if [ "$(os)" = "macos" ] && command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$PUB" && ok "ssh: public key copied to your clipboard — just paste it into GitHub"
fi
log "After uploading, test with:  ssh -T git@github.com"
