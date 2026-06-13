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
| passwordless sudo | configures `/etc/sudoers.d/nopasswd` so you don't have to type `sudo` (prompts: "Enter your password for the first time for the last time") | — |
| git SSH key & commit attribution | configures global Git commit settings (`user.name`/`user.email`) and creates `dev-key` (`.priv`/`.pub`) if absent, added to agent, wired into config, and copied to clipboard | — |
| Homebrew | package manager (macOS only, if missing) | `brew` |
| jq | JSON CLI | `jq` |
| CLI utilities | git, ripgrep, fd, fzf, bat, wget, gnupg | `git`, `rg`, `fd`, `fzf`, `bat`, `wget`, `gpg` |
| Python (uv) | uv + CPython 3.11/3.12/3.13 (3.12 default) + ruff/ipython/httpie/pre-commit | `uv`, `python3`, `ruff` |
| nvm + Node.js | JS runtime installer (prompts for default major version, defaults to 24) | `node`, `npm` |
| Shell prompt | colored `username@hostname` PS1 for zsh + bash (green/blue) | — |
| tmux & `dev` | terminal multiplexer + sensible config + instant `dev` session script | `tmux`, `dev` |
| GitHub CLI | `gh` | `gh` |
| Atlassian CLI | Jira/Confluence/Bitbucket CLI (tap `atlassian/homebrew-acli`) | `acli` |
| Docker + Compose | Docker Desktop on macOS (or Colima via `DOCKER_RUNTIME=colima`); Docker Engine on Linux | `docker`, `docker compose` |
| Ollama | local LLM server, started + enabled at boot | `ollama` |
| Hugging Face CLI | model/dataset downloads from huggingface.co | `hf` |
| MLX + mlx-lm | Apple's local-inference framework + server (Apple Silicon only) | `mlx_lm.server` |
| Claude Code | Anthropic CLI (plus custom status panel) | `claude` |
| Codex | OpenAI CLI (`@openai/codex`) | `codex` |
| opencode | sst/opencode (`opencode-ai`) | `opencode` |
| Grok | xAI CLI | `agent` |
| Cursor | Cursor agent CLI (aliased `cursor`) | `cursor-agent` |
| Antigravity | Google CLI (replaces gemini-cli) | `antigravity` |
| Kimi | Moonshot Kimi Code CLI | `kimi` |
| Agent settings | disable Co-Authored-By git trailers (Claude + Codex) | — |

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

## Passwordless sudo

On first run, if passwordless `sudo` is not already configured, the installer offers to create `/etc/sudoers.d/nopasswd` to authorize your user for passwordless privilege escalation:

```
<username> ALL=(ALL) NOPASSWD: ALL
```

This is highly recommended for agentic coding and local automation workflows (e.g., background agent processes installing packages or managing containers) so that they do not get blocked waiting for a password prompt.

The installer will ask for consent, displaying a brief explanation of the risks, and prompts you to:

> **"Enter your password for the first time for the last time."**

If you choose not to configure it, the installer will skip the setup and continue normally.

## git SSH key & commit attribution

On first run, if a key matching `~/.ssh/dev-key-*` doesn't exist (or if global git config name/email are missing), the installer prompts you to configure your global Git commit settings (`user.name` and `user.email`) and offers to generate an ed25519 key pair usable with any git host:

- `~/.ssh/dev-key-{username}.priv` — private (chmod 600, added to the ssh-agent; on macOS, the keychain)
- `~/.ssh/dev-key-{username}.pub` — public (chmod 644, **this is the file you upload**)

It adds `Host` blocks for **github.com and bitbucket.org** to `~/.ssh/config`
pointing at the key (each only if not already present), prints the public key,
automatically copies it to the system clipboard (supporting macOS and Linux), and
offers to open the browser directly to the SSH settings page on GitHub and/or Bitbucket
for easy pasting. Test with `ssh -T git@github.com` (or `git@bitbucket.org`).

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

## Shell prompt

Runs just before tmux. If your shell rc has no `PS1` set yet, it offers to
install a colored `username@hostname:dir` prompt (green name, blue path) into `~/.zshrc` and `~/.bashrc` (both are
checked on macOS; at least `~/.bashrc` on Linux). Inside tmux the host shows as
`tmux`. It never clobbers an existing prompt.

You're shown the current username and hostname as defaults — press Enter to keep
them, or type your own. The script recommends using lowercase values and automatically sanitizes
inputs (converting to lowercase, replacing spaces with hyphens, and removing Irish fadas or accented characters).
On macOS, if you pick a hostname different from the machine's, it asks (required y/n) whether to also
change the actual **local hostname** (System Settings → Sharing → `hostname.local`, e.g., `croi.local`) via `scutil`. Whatever name you
choose carries over as the default for the tmux status-bar prompt, so you can
press Enter there to use the same one.

## tmux & the `dev` command

First run prompts for a name shown in the tmux status bar (lowercased, spaces
stripped). The current/derived name is shown in parentheses — press Enter to
accept it. On later runs it reuses the name already baked into `~/.tmux.conf`,
so updates never re-prompt. An existing `~/.tmux.conf` is backed up to
`~/.tmux.conf.bak.<timestamp>` before being rewritten. Reload inside tmux with
`prefix + r` (prefix is `C-b`, with `C-a` as a secondary).

### The `dev` command
The installer places a convenience `dev` script in `~/.local/bin/dev` (which is typically loaded onto your path). Typing `dev` in your shell will:
- Automatically attach to an existing tmux session named `dev` if it is already running.
- Create and start a new tmux session named `dev` if it isn't running yet.

This makes starting or returning to your active development environment instantaneous.

Config highlights: vi copy-mode (`v`/`y`), mouse on, `|`/`-` splits that keep
the current path, Alt+arrows to move panes, Shift+arrows to switch windows,
50k-line scrollback.

## Agent settings

Runs last, after all agentic CLIs are installed. It configures AI coding tools to stop them from appending automatic `Co-Authored-By` or "Generated by..." attribution trailers to your git commit messages.

### Why disable commit attribution?
By default, tools like Claude Code and Codex write metadata or co-author details into every git commit they generate. While helpful for tracking, this can:
- Clutter commit messages and logs.
- Distort contributor statistics on platforms like GitHub or GitLab.
- Violate corporate commit linting policies, pre-commit hooks, or templates that enforce strict formatting.

### Configured settings:
- **Claude Code** (`~/.claude/settings.json`):
  - Sets `includeCoAuthoredBy` to `false`.
  - Installs a custom status panel script (`~/.claude/statusline.sh`) and configures `statusLine` to display real-time session stats (hostname, working directory, git branch, active model, context usage bar, cost, duration, and files modified).
- **Codex** (`~/.codex/config.toml`): Sets `commit_attribution` to `""`.

### Safety & Compatibility:
- **Non-destructive updates**: Only the specific attribution configurations are changed. Your existing configurations, including authentication tokens, project settings, and custom MCP server setups, are left completely untouched.
- **Automatic Backups**: Before editing any configuration files, the script creates a timestamped backup copy (e.g., `settings.json.bak.YYYYMMDD-HHMMSS`) in the same directory.
- **Other agents**: Tools like Cursor and opencode also append commit attribution trailers but do not currently expose a documented configuration flag to disable them. Grok, Kimi, and Antigravity do not append commit trailers by default.
- **Permissions**: This script strictly configures user-level settings files and does not modify system permissions, shell sandboxing, or security frameworks.

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

tmux config and tool install recipes mirror the maintainer's personal
`macos-toolkit` bootstrap, stripped of all personal / machine-specific
configuration.
