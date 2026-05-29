#!/usr/bin/env bash
# agent-settings — stop AI coding CLIs from stamping "Co-Authored-By" /
# "Generated with …" trailers onto your git commits. Conservative + idempotent:
# only the attribution key in each tool's config is touched; everything else
# (MCP servers, auth, preferences) is left exactly as-is. Backs up before any
# change. Runs after the agentic CLIs are installed.
#
#   Claude Code   ~/.claude/settings.json    includeCoAuthoredBy = false
#   Codex         ~/.codex/config.toml        commit_attribution  = ""
#
# Not touched: Cursor and opencode also add trailers but expose no documented
# off-switch yet; grok / kimi / antigravity have none known. Revisit when docs
# surface. (This installer does NOT change permission/sandbox modes.)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# ── Claude Code ──────────────────────────────────────────────────────────────
claude_settings="$HOME/.claude/settings.json"
if command -v claude >/dev/null 2>&1 || [ -e "$claude_settings" ]; then
  if command -v jq >/dev/null 2>&1; then
    mkdir -p "$HOME/.claude"
    [ -f "$claude_settings" ] || printf '{}\n' > "$claude_settings"
    tmp="$(mktemp)"
    if jq '.includeCoAuthoredBy = false' "$claude_settings" > "$tmp" 2>/dev/null; then
      if cmp -s "$tmp" "$claude_settings"; then
        rm -f "$tmp"; ok "agent-settings: claude already has includeCoAuthoredBy=false"
      else
        [ -s "$claude_settings" ] && cp -p "$claude_settings" "$claude_settings.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$tmp" "$claude_settings"; chmod 600 "$claude_settings" 2>/dev/null || true
        ok "agent-settings: claude includeCoAuthoredBy=false"
      fi
    else
      rm -f "$tmp"; warn "agent-settings: $claude_settings isn't valid JSON — skipping"
    fi
  else
    warn "agent-settings: jq missing — skipping Claude settings"
  fi
fi

# ── Codex ────────────────────────────────────────────────────────────────────
codex_cfg="$HOME/.codex/config.toml"
if command -v codex >/dev/null 2>&1 || [ -f "$codex_cfg" ]; then
  mkdir -p "$HOME/.codex"
  existed=0; [ -s "$codex_cfg" ] && existed=1
  [ -f "$codex_cfg" ] || : > "$codex_cfg"
  tmp="$(mktemp)"
  if grep -qE '^[[:space:]]*commit_attribution[[:space:]]*=' "$codex_cfg"; then
    sed 's|^[[:space:]]*commit_attribution[[:space:]]*=.*|commit_attribution = ""|' "$codex_cfg" > "$tmp"
  else
    # A top-level key must precede any [section]; prepend it to the very top.
    { printf 'commit_attribution = ""\n'; cat "$codex_cfg"; } > "$tmp"
  fi
  if cmp -s "$tmp" "$codex_cfg"; then
    rm -f "$tmp"; ok "agent-settings: codex commit_attribution already disabled"
  else
    [ "$existed" = 1 ] && cp -p "$codex_cfg" "$codex_cfg.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$tmp" "$codex_cfg"
    ok "agent-settings: codex commit_attribution disabled"
  fi
fi

ok "agent-settings: done"
