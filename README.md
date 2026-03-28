# dotfiles

A collection of docker, gdb, git, vim, neovim, zsh, ranger, conda, pip, npm and tmux configuration files and setup script under various OS.

## One-Click Install (Recommended)

On a fresh machine, run one command to set up everything:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/magic3007/dotfiles/master/bootstrap.sh)
```

This will:

1. **SSH Key** — check or generate `~/.ssh/id_ed25519`, prompt you to add it to [GitHub](https://github.com/settings/keys)
2. **Claude Code** — install Node.js (via nvm) and [Claude Code CLI](https://claude.ai/code)
3. **API Config** — prompt for `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`, `ANTHROPIC_AUTH_TOKEN` (defaults to [VolcEngine Coding Plan](https://www.volcengine.com/docs/82379/1928262?lang=zh) / doubao-seed-2.0-lite)
4. **Auto Setup** — launch Claude Code to clone this repo, run `./install`, configure git user, and install [wechat-reminder](https://github.com/magic3007/wechat-reminder)

Environment variables are saved to `~/.common_shell_setup_local.sh` (not tracked by git).

## Manual Install

```bash
git clone --recursive https://github.com/magic3007/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install
```

Dotfiles use [Dotbot](https://github.com/anishathalye/dotbot) for installation. The install script is idempotent: it can safely be run multiple times.

## What's Included

| Category | Tools |
|----------|-------|
| Shell | oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting, zsh-vi-mode, autojump, fzf |
| Editor | vim, neovim, ideavim |
| Terminal | tmux, zellij |
| File Manager | ranger |
| Git | gitconfig with aliases, custom hooks |
| AI Tools | Claude Code (`cc`, `sdcc`, `dscc`, `kmcc`), Codex (`cx`), Gemini (`gm`), Opencode (`oc`) |
| Package Mirrors | npm, pip, conda, cargo, Go, Julia, Flutter (CN mirrors) |
| macOS | Homebrew, Karabiner, skhd, Cursor, iTerm2 |
| Utilities | wechat-reminder, lazygit |

## AI Tool Aliases

After installation, these shell aliases are available:

```bash
sdcc    # Claude Code + VolcEngine (doubao-seed-2.0-lite)
cc      # Claude Code (native Anthropic API)
dscc    # Claude Code + DeepSeek
kmcc    # Claude Code + Kimi
mmcc    # Claude Code + MiMo
cx      # OpenAI Codex
gm      # Google Gemini CLI
oc      # Opencode
```

## Local Customization

Machine-specific overrides go in `*_local` files (not tracked by git):

| File | Purpose |
|------|---------|
| `~/.gitconfig_local` | git user name/email |
| `~/.zsh_local` | zsh customization |
| `~/.common_shell_setup_local.sh` | env vars (`VE_CODE_API_KEY`, `FEISHU_WEBHOOK_URL`, etc.) |

## Reference

- [Dotbot](https://github.com/anishathalye/dotbot)
- [nulloneguy/dotfiles](https://github.com/nulloneguy/dotfiles)
