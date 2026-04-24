# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Dotfiles repository using [Dotbot](https://github.com/anishathalye/dotbot) for installation. Stores configuration files and symlinks them to their standard locations (`~/.zshrc`, `~/.gitconfig`, `~/.config/nvim`, etc.).

## Commands

```bash
./install              # Full installation (idempotent, safe to re-run)
./install -n           # Dry run — preview what would be installed
git submodule update --init --recursive  # Update Vim plugins
```

## Architecture

### Two-Phase Installation (`install.conf.yaml`)

- **Phase 1 — Local**: Defaults, directory creation, submodules, backup existing configs, symlinks. No network required, always succeeds.
- **Phase 2 — Network**: Homebrew, platform packages, oh-my-zsh + plugins, fzf, Node.js/nvm, GitHub CLI, AI coding tools. All commands use `--connect-timeout` / `|| true` to avoid blocking without network.

### Symlink Model

All configs live in this repo and are symlinked to `~` via Dotbot. The `link` section in `install.conf.yaml` is the single source of truth for what gets symlinked where. When adding new configs: add files to the repo, then add symlink entries to `install.conf.yaml`.

### Local Customization Pattern

Machine-specific overrides go in `*_local` files (not tracked by git):
- `~/.gitconfig_local` — local git user/config (included via `[include]` in gitconfig)
- `~/.zsh_local` — local zsh config
- `~/.common_shell_setup_local.sh` — local shell setup (bash/zsh)
- `~/.config/fish/conf.d/local.fish` — local fish config

### Shell Setup

Three shells are supported: zsh, bash, and fish.

**bash/zsh**: `common_shell_setup.sh` is sourced by both `.zshrc` and `.bashrc`. It contains shared aliases, functions, env vars, and AI tool wrappers.

**fish**: `fish/` directory is symlinked to `~/.config/fish/`. Fish config is maintained separately (not sourced from `common_shell_setup.sh`) because fish syntax is incompatible with POSIX shell. Structure:
- `config.fish` — tool initialization (starship, zoxide, conda, venv)
- `conf.d/` — modular config (env vars, PATH, aliases, fzf, ssh)
- `functions/` — lazy-loaded functions (one per file, fish best practice)
- `fish_plugins` — Fisher plugin list
- AI tool wrappers use `_claude_with_api` helper function to reduce duplication

Common features across all shells:
- Safe `rm` override: `rm` is aliased to a warning; use `rem` for reversible delete or `\rm` for real delete
- Safe `mv`/`cp`: aliased with `-i` (interactive) flags
- Docker helper functions: `docker-run`, `docker-slave`, `docker-run-gui`
- AI tool shell aliases (see below)

### AI Tool Integration

Shell aliases and wrapper functions in `common_shell_setup.sh`:
- `cc` — Claude Code (`claude --dangerously-skip-permissions`)
- `cx` — OpenAI Codex (`codex --full-auto`)
- `gm` — Google Gemini CLI (`gemini --yolo`)
- `oc` — Opencode
- `dscc()` — Claude Code with DeepSeek API backend
- `kmcc()` / `kmcc2()` — Claude Code with Kimi API (via OpenRouter / direct)
- `mxcc()` — Claude Code with MiniMax via OpenRouter
- `qwcc()` — Claude Code with Qwen3.5 via Aliyun

### Claude Code Configuration (`claude/`)

Symlinked to `~/.claude/`. Contains:
- `settings.json` — permissions, hooks, language (Chinese), plugins, env vars
- `config.json` — API key config
- `commands/` — slash commands (`create-pr`, `gen-commit-msg`, `pr-review`)
- `hooks/` — PostToolUse and UserPromptSubmit hooks
- `rules/` — global rules (e.g., `debug-experience.md`)

### Chinese Mirrors

Package managers are configured with Chinese mirrors for faster downloads:
- Rust (rsproxy.cn), Go (mirrors.aliyun.com), npm (`.npmrc`), pip (`pip.conf`), Conda/Mamba (`.condarc`/`.mambarc`), Julia (TUNA), Flutter (flutter-io.cn)

### Git Configuration

- `pull.ff = only` — fast-forward only pulls
- `push.default = upstream` — push to upstream tracking branch
- `user.useConfigOnly = true` — requires explicit user config
- `core.hooksPath = ~/.git-hooks` — custom hooks directory
- `safe.directory = *` — trusts all directories
- Extensive aliases: `st` (status), `co` (checkout), `di` (diff), `dc` (diff cached), `gr` (graph log), etc.

### Cross-Platform

- **Linux**: apt-get for zsh, tmux, vim, htop, ranger, fish
- **macOS**: Homebrew for rg, lazygit, zellij, fish; Cursor/Antigravity editor config symlinks; Karabiner keyboard remapping; skhd window management; iTerm2 configuration sync via `~/.config/iterm2`

### wechat-reminder (`wechat-reminder/`)

通知工具，支持 WeChat (PushDeer) 和飞书双通道。通过 Claude Code hook（Stop/StopFailure/TaskCompleted）自动发送任务完成通知。

- `install.conf.yaml` 只复制 `wechat-reminder` 和 `wechat-reminder_main.py` 到 `~/.wechat-reminder/`，新增功能必须放在这两个文件内
- 飞书 `lark_md` **不支持** Markdown 表格语法（`| col | col |`），`wechat-reminder_main.py` 中的 `parse_content_segments()` 会自动将 Markdown 表格转换为飞书原生 `table` 卡片元素
- 单张卡片最多 5 个表格，超出降级为纯文本
- 环境变量：`FEISHU_WEBHOOK_URL`（飞书 webhook，支持逗号分隔多个）、`PUSHDEER_KEY`（微信推送）

### Adding New Configs

When adding new dotfile configs:
1. Add the config file to this repo
2. Add a symlink entry to the `link` section in `install.conf.yaml`
3. If platform-specific, wrap in a shell condition: `test "$(uname)" = "Darwin" && ...`
