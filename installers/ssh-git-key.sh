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

# True if the `Host <host>` block in $cfg already references our dev-key.
host_block_has_key() {
  local host="$1" cfg="$2"
  [ -f "$cfg" ] || return 1
  awk -v host="$host" '
    tolower($1)=="host" { inblk=0; for (i=2;i<=NF;i++) if ($i==host) inblk=1; next }
    inblk { print }
  ' "$cfg" | grep -qiE 'IdentityFile[[:space:]]+.*dev-key\.priv'
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
if [ "$(os)" = "macos" ] && command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$PUB" && ok "ssh: public key copied to your clipboard — just paste it in"
fi
log "After uploading, test with:  ssh -T git@github.com   (or git@bitbucket.org)"
