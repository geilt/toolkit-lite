#!/usr/bin/env bash
# python — uv (Astral) + uv-managed CPython + a few global Python CLI tools.
# Install/update, idempotent. Works the same on macOS and Linux.
#
# uv is the one tool that replaces the rest:
#   uv venv / uv run    → no hand-rolled venvs
#   uv tool install / uvx → no pipx
#   uv python install   → no pyenv (manages CPython versions)
#   uv add / uv sync    → project deps (no global pip installs)
#
# We install Python 3.11, 3.12, 3.13 side by side and make 3.12 the default
# `python`/`python3`. No global *libraries* are installed (those belong in
# per-project envs); only a handful of broadly useful global CLI tools.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PY_VERSIONS="3.11 3.12 3.13"
PY_DEFAULT="3.12"
UV_TOOLS="ruff ipython httpie pre-commit"

# uv's executables (and the --default python/python3 shims) land here.
export PATH="$HOME/.local/bin:$PATH"

# 1. uv — install via Astral's script (uniform on macOS + Linux), or update.
if command -v uv >/dev/null 2>&1; then
  log "uv: present — updating"
  uv self update 2>/dev/null \
    || { [ "$(os)" = "macos" ] && ensure_brew_on_path && brew upgrade uv 2>/dev/null; } \
    || true
else
  log "uv: installing (astral.sh)"
  curl -LsSf https://astral.sh/uv/install.sh | sh || die "uv: install failed"
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || die "uv: not on PATH after install"
ok "uv: $(uv --version 2>/dev/null)"

# 2. CPython versions (3.12 default → provides python/python3 on PATH).
log "uv: installing CPython $PY_VERSIONS (default $PY_DEFAULT)"
uv python install $PY_VERSIONS || warn "uv: some python versions failed to install"
uv python install --default "$PY_DEFAULT" 2>/dev/null \
  || uv python install --default --preview "$PY_DEFAULT" 2>/dev/null \
  || warn "uv: couldn't set default python3 shim (use 'uv run'/'uvx' instead)"

# 3. Global CLI tools (isolated envs via uv tool; not global libraries).
log "uv: installing/updating global tools: $UV_TOOLS"
for t in $UV_TOOLS; do
  if uv tool list 2>/dev/null | grep -q "^$t "; then
    uv tool upgrade "$t" 2>/dev/null || true
  else
    uv tool install "$t" || warn "uv tool install $t failed"
  fi
done

# 3b. venv safety net. `venv` ships with CPython — uv's managed pythons include
#     it, and `uv venv` doesn't even need it. The ONE exception is Debian/Ubuntu,
#     which split the *system* python's venv/ensurepip into the python3-venv apt
#     package. Ensure it's present so a plain `/usr/bin/python3 -m venv` works for
#     anyone using the system interpreter directly. (No-op on macOS/dnf/yum,
#     where venv ships with the base python.)
if [ "$(os)" = "linux" ] && [ "$(linux_pkg_mgr)" = "apt" ] \
   && [ -x /usr/bin/python3 ] && ! /usr/bin/python3 -c 'import ensurepip, venv' >/dev/null 2>&1; then
  log "python: system python3 lacks venv — installing python3-venv (Debian/Ubuntu splits it out)"
  pkg_install python3-venv || warn "python: python3-venv install failed"
fi

# 4. Make sure uv's bin dir (python3 shim + tool executables) is on PATH in
#    future shells (edits your shell rc; harmless if already present).
uv tool update-shell 2>/dev/null || true

# 5. Report.
if command -v python3 >/dev/null 2>&1; then
  ok "python3: $(python3 --version 2>&1) ($(command -v python3))"
else
  log "python3: open a new shell so uv's bin dir loads onto PATH"
fi
ok "python: done — uv manages versions ('uv python list') and tools ('uv tool list')"
