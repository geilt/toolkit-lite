# toolkit-lite

A small, portable installer that sets up (and keeps up to date) the everyday
CLI toolchain for AI-assisted development. Run it once to install; re-run any
time to update everything to the latest.

No personal config, no secrets, no machine-specific assumptions — safe to fork,
share, and run on a fresh Mac (or Linux box).

## Quick install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)"
```

## What it installs

| Component | What | Binary |
|---|---|---|
| `~/environment` | folder for your repos (created if missing) | — |
| git SSH key | `dev-key` (`.priv`/`.pub`) created if absent, added to agent, wired into `~/.ssh/config` for GitHub + Bitbucket; tells you which file to upload | — |
| Homebrew | package manager (macOS only, if missing) | `brew` |
| jq | JSON CLI | `jq` |
| CLI utilities | ripgrep, fd, fzf, bat, wget, gnupg | `rg`, `fd`, `fzf`, `bat`, `wget`, `gpg` |
| Python (uv) | uv + CPython 3.11/3.12/3.13 (3.12 default) + ruff/ipython/httpie/pre-commit | `uv`, `python3`, `ruff` |
| nvm + Node LTS | JS runtime (needed by codex/opencode) | `node`, `npm` |
| tmux | terminal multiplexer + a sensible config (vi keys, mouse, status bar) | `tmux` |
| GitHub CLI | `gh` | `gh` |
| Atlassian CLI | Jira/Confluence/Bitbucket CLI (tap `atlassian/homebrew-acli`) | `acli` |
| Docker + Compose | Docker Desktop on macOS (or Colima via `DOCKER_RUNTIME=colima`); Docker Engine on Linux | `docker`, `docker compose` |
| Ollama | local LLM server, started + enabled at boot | `ollama` |
| Hugging Face CLI | model/dataset downloads from huggingface.co | `hf` |
| MLX + mlx-lm | Apple's local-inference framework + server (Apple Silicon only) | `mlx_lm.server` |
| Claude Code | Anthropic CLI | `claude` |
| Codex | OpenAI CLI (`@openai/codex`) | `codex` |
| opencode | sst/opencode (`opencode-ai`) | `opencode` |
| Grok | xAI CLI | `agent` |
| Cursor | Cursor agent CLI (aliased `cursor`) | `cursor-agent` |
| Antigravity | Google CLI (replaces gemini-cli) | `antigravity` |
| Kimi | Moonshot Kimi Code CLI | `kimi` |

## Usage

One-liner (clones into `~/environment/toolkit-lite`, then runs the installer):

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)"
# wget works too:
bash -c "$(wget -qO- https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)"
# pass flags through after a --, e.g.:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/geilt/toolkit-lite/main/bootstrap.sh)" -- --only node,tmux
```

Or clone it yourself:

```sh
git clone git@github.com:geilt/toolkit-lite.git ~/environment/toolkit-lite
cd ~/environment/toolkit-lite
./install.sh                  # install/update everything (prompts once for a tmux name)
```

Keep things current later:

```sh
cd ~/environment/toolkit-lite
git pull
./install.sh --update         # update all, no prompts
```

Other flags:

```sh
./install.sh --only tmux,node          # run just specific components
TOOLKIT_LITE_USERNAME=sam ./install.sh   # preset the tmux status-bar name
```

After it finishes, open a new shell (or `exec $SHELL -l`) so PATH and nvm load.

## git SSH key

On first run, if `~/.ssh/dev-key.priv` doesn't exist, the installer offers to
generate an ed25519 key pair usable with any git host:

- `~/.ssh/dev-key.priv` — private (chmod 600, added to the ssh-agent; on macOS, the keychain)
- `~/.ssh/dev-key.pub` — public (chmod 644, **this is the file you upload**)

It adds `Host` blocks for **github.com and bitbucket.org** to `~/.ssh/config`
pointing at the key (each only if not already present), prints the public key
(and copies it to the clipboard on macOS), and tells you where to add it
(GitHub → Settings → SSH and GPG keys; Bitbucket → Personal settings → SSH
keys). Test with `ssh -T git@github.com` (or `git@bitbucket.org`).

If the key already exists, the installer leaves it untouched and never
re-prompts — it just makes sure it's loaded in the agent. Keys live in `~/.ssh`
directly; this tool deliberately does **not** use any shared/iCloud folder.

## Docker

macOS installs **Docker Desktop** (cask) by default. On a headless/remote Mac
(no GUI), run `DOCKER_RUNTIME=colima ./install.sh --only docker` to use
**Colima** instead (lightweight, SSH-friendly; start it with `colima start`).
Linux installs the Docker Engine via the official script. Compose v2 is the
`docker compose` subcommand in all cases.

## Local inference (Ollama / MLX / Hugging Face)

`./install.sh --only ai-local` sets up a local model stack:

- **Ollama** — installed and started as a background service (macOS via
  `brew services`, Linux via systemd), so the API on `:11434` is up after a
  reboot. Pull a model with `ollama pull qwen2.5-coder` when you want one.
- **Hugging Face CLI** (`hf`) — for fetching models/datasets from the Hub.
- **MLX + mlx-lm** — **Apple Silicon only** (skipped on Intel/Linux). Installed
  into a dedicated `python@3.12` venv at `~/.local/mlx`, with an
  OpenAI-compatible `mlx_lm.server` running as a LaunchAgent on `:11435`
  (loads models on demand — nothing is pre-downloaded).

No models are pre-pulled; both servers fetch on first use.

## Python (uv)

Installs [uv](https://docs.astral.sh/uv/) — one fast binary that replaces
`venv`, `pipx`, `pyenv`, and `pip`/`poetry` for most workflows:

```sh
uv venv / uv run …      # ephemeral or project envs (no manual venv)
uv python install 3.13  # manage CPython versions (no pyenv)
uv tool install <cli>   # global CLI tools, isolated (no pipx); uvx <cli> to run once
uv add / uv sync        # project dependencies (no global pip installs)
```

It installs CPython **3.11, 3.12, 3.13** side by side and makes **3.12** the
default `python`/`python3`. (No global libraries — those belong in per-project
envs via `uv add`.) Standardized global tools: **ruff** (lint/format),
**ipython**, **httpie** (`http`), **pre-commit**. Python 2 is intentionally not
installed (EOL since 2020); guaranteeing a real `python3` avoids the old
`python` ambiguity.

## tmux

First run prompts for a name shown in the tmux status bar (lowercased, spaces
stripped). On later runs it reuses the name already baked into `~/.tmux.conf`,
so updates never re-prompt. An existing `~/.tmux.conf` is backed up to
`~/.tmux.conf.bak.<timestamp>` before being rewritten. Reload inside tmux with
`prefix + r` (prefix is `C-b`, with `C-a` as a secondary).

Config highlights: vi copy-mode (`v`/`y`), mouse on, `|`/`-` splits that keep
the current path, Alt+arrows to move panes, Shift+arrows to switch windows,
50k-line scrollback.

## Layout

```
toolkit-lite/
├── install.sh          # entry point (install + update, idempotent)
├── lib.sh              # helpers: logging, OS detection, brew/pkg install
├── installers/         # one self-contained, re-runnable script per tool
│   ├── node.sh  tmux.sh
│   ├── claude-code.sh  codex.sh  opencode.sh
│   └── grok.sh  cursor.sh  antigravity.sh  kimi.sh
└── config/
    └── tmux.conf.template   # rendered to ~/.tmux.conf with your name
```

Each `installers/*.sh` is standalone — run one directly to (re)install just
that tool, e.g. `bash installers/codex.sh`.

## Notes / soft spots

- **macOS + common Linux** (apt/dnf/yum). Tested primarily on macOS.
- **Antigravity / Kimi** binary names are best-effort (`antigravity`/`gemini`,
  `kimi`/`kimi-code`); the installers warn if the expected name isn't on PATH
  after install.
- **Grok** installs its binary as `agent`; detection is path-based to avoid
  clobbering an unrelated `agent` on PATH.
- Vendors change install URLs occasionally; if one breaks, the fix is the
  `INSTALL_URL` / package name at the top of that tool's installer.

## Credits

tmux config adapted from the TLD Toolkit. Tool install recipes mirror the
maintainer's personal `macos-toolkit` bootstrap, stripped of all personal /
machine-specific configuration.
