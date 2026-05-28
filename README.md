# toolkit-light

A small, portable installer that sets up (and keeps up to date) the everyday
CLI toolchain for AI-assisted development. Run it once to install; re-run any
time to update everything to the latest.

No personal config, no secrets, no machine-specific assumptions — safe to fork,
share, and run on a fresh Mac (or Linux box).

## What it installs

| Component | What | Binary |
|---|---|---|
| `~/environment` | folder for your repos (created if missing) | — |
| GitHub SSH key | `dev-key` (`.priv`/`.pub`) created if absent, added to agent, wired into `~/.ssh/config`; tells you which file to upload | — |
| Homebrew | package manager (macOS only, if missing) | `brew` |
| jq | JSON CLI | `jq` |
| nvm + Node LTS | JS runtime (needed by codex/opencode) | `node`, `npm` |
| tmux | terminal multiplexer + a sensible config (vi keys, mouse, status bar) | `tmux` |
| Claude Code | Anthropic CLI | `claude` |
| Codex | OpenAI CLI (`@openai/codex`) | `codex` |
| opencode | sst/opencode (`opencode-ai`) | `opencode` |
| Grok | xAI CLI | `agent` |
| Cursor | Cursor agent CLI (aliased `cursor`) | `cursor-agent` |
| Antigravity | Google CLI (replaces gemini-cli) | `antigravity` |
| Kimi | Moonshot Kimi Code CLI | `kimi` |

## Usage

```sh
git clone <this-repo> ~/environment/toolkit-light
cd ~/environment/toolkit-light
./install.sh                  # install/update everything (prompts once for a tmux name)
```

Keep things current later:

```sh
cd ~/environment/toolkit-light
git pull
./install.sh --update         # update all, no prompts
```

Other flags:

```sh
./install.sh --only tmux,node          # run just specific components
TOOLKIT_LIGHT_USERNAME=sam ./install.sh  # preset the tmux status-bar name
```

After it finishes, open a new shell (or `exec $SHELL -l`) so PATH and nvm load.

## GitHub SSH key

On first run, if `~/.ssh/dev-key.priv` doesn't exist, the installer offers to
generate an ed25519 key pair:

- `~/.ssh/dev-key.priv` — private (chmod 600, added to the ssh-agent; on macOS, the keychain)
- `~/.ssh/dev-key.pub` — public (chmod 644, **this is the file you upload to GitHub**)

It also adds a `Host github.com` block to `~/.ssh/config` pointing at the key
(only if one isn't already there), prints the public key (and copies it to the
clipboard on macOS), and tells you to add it at **GitHub → Settings → SSH and
GPG keys → New SSH key**. Test with `ssh -T git@github.com`.

If the key already exists, the installer leaves it untouched and never
re-prompts — it just makes sure it's loaded in the agent. Keys live in `~/.ssh`
directly; this tool deliberately does **not** use any shared/iCloud folder.

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
toolkit-light/
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
