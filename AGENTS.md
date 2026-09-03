# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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
- `cc` — Codex (`Codex --dangerously-skip-permissions`)
- `cx` — OpenAI Codex (`codex --full-auto`)
- `gm` — Google Gemini CLI (`gemini --yolo`)
- `oc` — Opencode
- `dscc()` — Codex with DeepSeek API backend
- `kmcc()` / `kmcc2()` — Codex with Kimi API (via OpenRouter / direct)
- `mxcc()` — Codex with MiniMax via OpenRouter
- `qwcc()` — Codex with Qwen3.5 via Aliyun

### Skills tool (`skills` CLI) — do NOT use `-g`

`npx skills add <pkg> -g` (global) writes symlinks into `~/.claude/skills`, `~/.cursor/skills`, `~/.pi/agent/skills`, etc. Since `~/.claude/skills` and `~/.cursor/skills` are symlinks into this repo's `claude/skills/`, the relative symlinks it creates are **broken** (e.g. `lark-apps -> ../../.agents/skills/lark-apps` resolves to the repo root instead of `~`). This previously replaced the tracked `claude/skills/lark-*` files and showed up as mass deletions in git.

Rules:
- **Never run `npx skills add <pkg> -g`** — it corrupts `claude/skills/`.
- lark-* skills are **not tracked** in this repo anymore (see `.gitignore`). They live in `~/.agents/skills/` (source) and `~/.pi/agent/skills/` (working symlinks); they're also embedded in lark-cli (`lark-cli skills read`).
- To add a skill from a package: copy the skill dir into this repo manually and track it, or install it only into the agent that uses it (project-scope, not `-g`).

### AI Tool Configurations (`Codex/`, `codex/`, `gemini/`, `opencode/`, `pi/`)

Each AI coding tool has its own config directory symlinked to `~/`:
- `Codex/` → `~/.Codex/` — Codex settings, hooks, skills, rules, commands, agents
- `codex/` → `~/.codex/` — OpenAI Codex config and env
- `gemini/` → `~/.gemini/` — Gemini CLI settings
- `opencode/` → `~/.config/opencode/` — Opencode config
- `pi/` → `~/.pi/agent/` — Pi agent settings, models, extensions

**Pi extensions** (`pi/extensions/` → `~/.pi/agent/extensions/`): TypeScript 扩展，通过 `pi.on()` 订阅生命周期事件。现有扩展：
- `pi-end-reminder.ts` — 监听 `agent_settled` 事件，任务完成后通过 `~/.local/bin/wechat-reminder` 发送飞书/微信通知（对应 Claude Code 的 `claude-end-reminder.sh`）。默认通过环境变量 `END_REMINDER_ENABLE` 开关（默认关闭，见 wechat-reminder 节）。新扩展加到 `pi/extensions/` 即可自动被发现（`/reload` 热加载）。

**omp** (`omp/`, https://omp.sh, Stencil/oh-my-pi): a coding agent harness. Only `~/.omp/agent/config.yml -> omp/config.yml` is symlinked; the rest of `~/.omp/agent` (`*.db`, `sessions/`, `cache/`, ...) is runtime state and stays local. Hard constraints on `config.yml`: (1) it MUST remain writable — omp takes a native file lock, a read-only symlink breaks every launch; (2) it does NOT support comments — `omp config set` rewrites it as pure YAML and strips comments, so keep explanatory prose in `omp/README.md`, not in the file; (3) never commit `auth.*`/provider tokens/secrets. Install: `curl -fsSL https://omp.sh/install | sh` (→ `~/.bun/bin/omp`).

**Tool-specific skills**: Codex, Codex, and Gemini use independent skill directories:
- `Codex/skills/` -> `~/.Codex/skills`
- `codex/skills/` -> `~/.codex/skills`
- `gemini/skills/` -> `~/.gemini/skills`

Add a skill to each tool's own directory when it should be available there. Cursor currently keeps using `Codex/skills/` via `~/.cursor/skills`.

`claude/skills/ask-for-help/` is intentionally shared with Pi because
`pi/settings.json` loads `~/.claude/skills`. It stops repeated recovery after
five distinct failed attempts and prepares a Codex escalation packet.

**Codex native toil team**: `codex/config.toml` registers the Responses API
providers and a flat native team capped at 50 concurrent threads. Role files
live in `codex/agents/{dspix,glmpix}.toml`; orchestration policy lives in
`codex/skills/toil-offloading/`. Keep credentials in `DEEPSEEK_API_KEY` and
`ZAI_API_KEY`, never in tracked TOML. The skill treats configured native
roles as runtime-provided options and sends useful assignments directly without
role-availability or model/provider probes.

**Codex hooks** (`~/.codex/hooks/`，本地文件未入库):
- `check_dangerous_ops.sh` (PreToolUse) — blocks destructive git commands (`reset --hard`, `push --force`, `clean -f`, etc.), prevents writes to `/tmp/`, and intercepts file deletions outside safe directories
- `check-expert-update.sh` (PostToolUse) — reminds to update docs when editing configs/scripts
- `claudeception-activator.sh` (UserPromptSubmit) — triggers knowledge extraction evaluation
- `claude-end-reminder.sh` (Stop) — sends Feishu notifications on task completion via wechat-reminder; gated by `END_REMINDER_ENABLE` (default off)

**Safe directories**: `output/`, `test_output/`, `debug_output/` are whitelisted in `check_dangerous_ops.sh` — Codex can freely write/delete within these without prompts.

**Plugins** (in `settings.json`): superpowers (official), feishu, humanize — installed via marketplace system with `extraKnownMarketplaces` config.

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

- **Linux**: apt-get for zsh, tmux, vim, htop, ranger, fish (see `install-scripts/linux/`)
- **macOS**: Homebrew for rg, lazygit, zellij, fish (see `install-scripts/mac/`); Cursor/Antigravity editor config symlinks; Karabiner keyboard remapping; skhd window management; iTerm2 plist sync via `~/.config/iterm2`; Ghostty terminal config via `ghostty/config`

When adding new platform packages, edit the relevant `install-scripts/{linux,mac}/install-packages.sh`.

### wechat-reminder (`wechat-reminder/`)

通知工具，支持 WeChat (PushDeer) 和飞书双通道。通过 Claude Code hook（Stop/StopFailure/TaskCompleted）、Codex hook（Stop）和 Pi 扩展（`agent_settled`）自动发送任务完成通知。

**开关（默认关闭）**：环境变量 `END_REMINDER_ENABLE` 控制 Claude Code（`claude/hooks/claude-end-reminder.sh`）、Codex（`~/.codex/hooks/claude-end-reminder.sh`，本地未入库）和 Pi（`pi/extensions/pi-end-reminder.ts`）三个发送端。未设置 / 空 / `0` / `false` / `no` / `off` → 不发送；设置为 `1` / `yes` / `true` / `on` → 发送。启用示例：`END_REMINDER_ENABLE=1 claude` 或 `export END_REMINDER_ENABLE=1`。

- `install.conf.yaml` 只复制 `wechat-reminder` 和 `wechat-reminder_main.py` 到 `~/.wechat-reminder/`，新增功能必须放在这两个文件内
- 飞书 `lark_md` **不支持** Markdown 表格语法（`| col | col |`），`wechat-reminder_main.py` 中的 `parse_content_segments()` 会自动将 Markdown 表格转换为飞书原生 `table` 卡片元素
- 单张卡片最多 5 个表格，超出降级为纯文本
- 环境变量：`FEISHU_WEBHOOK_URL`（飞书 webhook，支持逗号分隔多个）、`PUSHDEER_KEY`（微信推送）

### Adding New Configs

When adding new dotfile configs:
1. Add the config file to this repo
2. Add a symlink entry to the `link` section in `install.conf.yaml`
3. If platform-specific, wrap in a shell condition: `test "$(uname)" = "Darwin" && ...`
