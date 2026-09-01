# dotfiles

My personal dotfiles — meticulously curated configurations for the ultimate terminal-centric development environment. Managed by [Dotbot](https://github.com/anishathalye/dotbot) with a two-phase installer that works across Linux and macOS.

<p align="center">
  <b>zsh</b> · <b>bash</b> · <b>fish</b> &nbsp;|&nbsp;
  <b>Linux</b> · <b>macOS</b> &nbsp;|&nbsp;
  <b>tmux</b> · <b>neovim</b> · <b>Claude Code</b>
</p>

## One-Click Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/magic3007/dotfiles/master/bootstrap.sh)
```

Bootstraps everything: SSH keys → Claude Code → repo clone → `./install` → git config → wechat-reminder. All API keys and env vars land in `~/.common_shell_setup_local.sh` (never committed).

<details>
<summary>Manual install</summary>

```bash
git clone --recursive https://github.com/magic3007/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install          # idempotent — safe to re-run
./install -n       # dry run
```
</details>

## What's Configured

### Shell & Prompt
| Tool | Config |
|------|--------|
| **zsh** | oh-my-zsh + autosuggestions + syntax-highlighting + vi-mode + autojump + wakatime |
| **bash** | shared aliases, functions, and env vars via `common_shell_setup.sh` |
| **fish** | Fisher plugins, lazy-loaded functions, modular conf.d structure |
| **starship** | Cross-shell prompt with custom styling |

### Terminal & Multiplexer
| Tool | Config |
|------|--------|
| **tmux** | Status bar, keybindings, mouse support |
| **cmux** | Session/tab/panel JSON config |
| **Warp** | Modern terminal settings |
| **iTerm2** | macOS — plist sync, custom profile |
| **Ghostty** | Cross-platform GPU terminal |
| **zellij** | (installed via Homebrew/apt) |

### Editor & IDE
| Tool | Config |
|------|--------|
| **neovim** | NvChad (full IDE) + nvim-basic-ide (lightweight), LSP, treesitter |
| **vim** | vimrc with plugin management, undo history, extensive settings |
| **VSCode** | Settings sync via `vscoderc` |
| **ideavim** | JetBrains Vim emulation |
| **Cursor** | macOS — keybindings + settings |
| **Antigravity** | macOS — keybindings + settings |

### Git
| Tool | Config |
|------|--------|
| **gitconfig** | Aliases (`st`/`co`/`di`/`dc`/`gr`…), fast-forward-only pull, custom hooks path |
| **lazygit** | (installed via Homebrew/apt) |

### File Management
| Tool | Config |
|------|--------|
| **ranger** | Plugins, rifle, custom commands, scope.sh |
| **joshuto** | Rust file manager — keymap, mimetype, theme |
| **yazi** | Rust file manager — keymap, theme |
| **lsd** | Modern `ls` replacement |

### AI Coding Tools
| Tool | Config |
|------|--------|
| **Claude Code** | Settings, hooks, skills, agents, commands, rules, API wrappers for 6+ backends |
| **Codex** | OpenAI Codex config, env, skills |
| **Gemini CLI** | Settings, skills |
| **Opencode** | Config, package.json |
| **Pi** | Models + settings |
| **Kimi Code** | config.toml |
| **ChatGPT** | Shell helper |

> **任务完成提醒开关（默认关闭）**：`END_REMINDER_ENABLE` 控制 Claude Code 和 Pi 任务结束时的 wechat-reminder 飞书/微信通知。设为 `1` 启用（如 `END_REMINDER_ENABLE=1 claude`），未设置 / `0` 时静默。

#### Shell Aliases
```bash
cc        # Claude Code — native Anthropic API
sdcc      # Claude Code — VolcEngine (doubao-seed-2.0-lite)
dscc      # Claude Code — DeepSeek (v4-flash)
dsccpro   # Claude Code — DeepSeek (v4-pro)
kmcc      # Claude Code — Kimi via OpenRouter
kmcc2     # Claude Code — Kimi direct
mxcc      # Claude Code — MiniMax via OpenRouter
mmcc      # Claude Code — MiMo
gm        # Google Gemini CLI
oc        # Opencode
```

### macOS Window Management
| Tool | Config |
|------|--------|
| **Karabiner** | Keyboard remapping, complex modifications, assets |
| **skhd** | Hotkey daemon |
| **yabai** | Tiling window manager |

### Language & Package Managers
| Tool | Config |
|------|--------|
| **cargo** | rsproxy.cn mirror |
| **pip** | TUNA mirror (tsinghua) |
| **conda / mamba** | TUNA mirror |
| **npm** | npmmirror.com |
| **R** | `.Rprofile` |

### Debugging & Profiling
| Tool | Config |
|------|--------|
| **gdb** | Dashboard, reverse engineering helpers, STL pretty-printers |

### Containers
| Tool | Config |
|------|--------|
| **Docker** | Dockerfiles for CUDA/PyTorch/Ubuntu dev environments, GUI setup guide |

### CLI Enhancements
| Tool | Config |
|------|--------|
| **bat** | `bat` — syntax-highlighted `cat` |
| **fzf** | Fuzzy finder |
| **yolo** | `~/.local/bin/yolo` — generic LLM-powered shell helper script |

### Productivity & Knowledge
| Tool | Config |
|------|--------|
| **Obsidian** | Plugins, appearance, core plugin settings |
| **wechat-reminder** | Dual-channel (WeChat PushDeer + Feishu webhook), Claude Code hook integration |

## Local Customization

Machine-specific overrides — gitignored:

| File | Purpose |
|------|---------|
| `~/.gitconfig_local` | Git user name/email |
| `~/.zsh_local` | Zsh overrides |
| `~/.bash_local` | Bash overrides |
| `~/.common_shell_setup_local.sh` | API keys, webhook URLs, env vars |
| `~/.config/fish/conf.d/local.fish` | Fish overrides |

## Architecture

```
dotfiles/
├── claude/          → ~/.claude/         Claude Code (hooks, skills, agents, settings)
├── codex/           → ~/.codex/          OpenAI Codex
├── gemini/          → ~/.gemini/         Google Gemini CLI
├── opencode/        → ~/.config/opencode/ Opencode
├── pi/              → ~/.pi/agent/       Pi coding agent
├── kimi-code/       → ~/.kimi-code/      Kimi Code
├── neovim/          → ~/.config/nvim/    NvChad + basic-ide
├── vim/             → ~/.vim_runtime/    Vim config + plugins
├── git/             → ~/.gitconfig       Git aliases + hooks
├── starship/        → ~/.config/starship.toml
├── fish/            → ~/.config/fish/    Fish shell
├── ranger/          → ~/.config/ranger/  Ranger file manager
├── joshuto/         → ~/.config/joshuto/ Joshuto file manager
├── yazi/            → ~/.config/yazi/    Yazi file manager
├── lsd/             → ~/.config/lsd/     LSD config
├── bat/             → ~/.config/bat/     Bat config
├── gdb/             → ~/.gdbinit + ~/.gdb/
├── ghostty/         → ~/.config/ghostty/
├── karabiner/       → ~/.config/karabiner/   (macOS)
├── skhd/            → ~/.skhdrc + ~/.skhd/   (macOS)
├── cursor_config/   → Cursor settings        (macOS)
├── antigravity_config/ → Antigravity settings (macOS)
├── iterm2/          → iTerm2 plist          (macOS)
├── obsidian/        → Obsidian vault settings
├── docker/          → Dev Dockerfiles
├── install-scripts/ → Platform package installers
└── wechat-reminder/ → Dual-channel notification tool
```

## Reference

- [Dotbot](https://github.com/anishathalye/dotbet) — dotfile management
- [CLAUDE.md](CLAUDE.md) — full development guide and constraints
