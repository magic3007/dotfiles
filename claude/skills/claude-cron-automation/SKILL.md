---
name: claude-cron-automation
description: |
  Run Claude Code commands (including /insights, /doctor, custom prompts) via system
  crontab in non-interactive mode. Use when: (1) setting up daily/weekly automated
  Claude Code tasks, (2) scheduling reports or analysis via cron, (3) running
  Claude Code with third-party API backends (DeepSeek, Qwen, etc.) in headless
  environments, (4) "set up a daily report", "automate this in cron", "schedule
  insights". Covers: cron PATH setup, third-party API env vars for non-interactive
  mode, nvm/node auto-discovery, and wechat-reminder integration for notification
  delivery.
author: Jing Mai
version: 1.0.0
date: 2026-07-27
---

# Claude Code Cron Automation

## Problem

Running Claude Code in cron requires solving three challenges that don't apply
to interactive sessions:
1. cron's minimal PATH doesn't include nvm/node or user binaries
2. Shell aliases and functions (like `dsccpro`) are unavailable
3. Third-party API backends need explicit environment variables

## Context / Trigger Conditions

- Setting up automated daily/weekly Claude Code tasks via cron
- `claude -p` non-interactive mode with API backends other than Anthropic
- `/insights`, `/doctor`, or custom prompts need to run on a schedule
- cron environment lacks `DEEPSEEK_API_KEY`, node, or `wechat-reminder` in PATH
- Need to deliver results via wechat-reminder (Feishu/WeChat)

## Solution

### 1. Crontab Entry Pattern

Always use `zsh -l` (login shell) to source the user's full environment:
```
7 22 * * * /bin/zsh -l '/absolute/path/to/script.sh'
```

The `-l` flag ensures `.zshenv`, `.zprofile`, and `.zshrc` are sourced, making
API keys and PATH available.

### 2. Script Self-Setup (Defense in Depth)

Even with `zsh -l`, include a self-setup section in the script for robustness:

```zsh
#!/bin/zsh
set -euo pipefail

# Auto-discover nvm/node (covers cron's minimal PATH)
for nvm_dir in "$HOME/.nvm" "/usr/local/nvm"; do
    if [[ -s "$nvm_dir/nvm.sh" ]]; then
        export NVM_DIR="$nvm_dir"
        break
    fi
done

NODE_BIN="$HOME/.nvm/versions/node/$(ls "$HOME/.nvm/versions/node/" 2>/dev/null | sort -V | tail -1 || echo '')/bin"
export PATH="$NODE_BIN:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Verify essentials
command -v claude >/dev/null 2>&1 || { echo "claude not found"; exit 1; }
```

### 3. Third-Party API Env Vars (Non-Interactive)

Shell aliases like `dsccpro` don't work in scripts. Use the raw env var pattern
that `_claude_with_api` expands to:

```zsh
# DeepSeek API (replaces dsccpro alias)
REPORT=$(
    env -u ANTHROPIC_API_KEY \
        ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
        ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}" \
        API_TIMEOUT_MS=600000 \
        ANTHROPIC_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_SMALL_FAST_MODEL="deepseek-v4-pro[1m]" \
        CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-pro[1m]" \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
        claude -p "$PROMPT" \
            --print \
            --output-format text \
            --dangerously-skip-permissions \
            --add-dir "$HOME/.claude/projects" \
            --add-dir "$HOME/.claude/usage-data" \
            2>&1
)
```

Key flags:
- `--dangerously-skip-permissions` — required for non-interactive; skips all permission prompts
- `--add-dir <path>` — explicitly allow file access to specific directories
- `--print --output-format text` — non-interactive text output (no TUI)

### 4. Built-in Commands in Non-Interactive Mode

These Claude Code built-in commands work with `claude -p`:

| Command | Behavior in `-p` mode |
|---------|----------------------|
| `/insights` | Generates HTML report at `~/.claude/usage-data/report-YYYY-MM-DD-HHMMSS.html` |
| `/doctor` | Outputs diagnostic report to stdout |
| `/context` | Outputs context usage to stdout |
| Custom prompt | Full tool access (Read, Bash, etc.) for multi-step workflows |

After running `/insights`, use Read to access the generated HTML report.

### 5. Multi-Step Prompt Design

Combine steps into a single `-p` call to avoid multiple API invocations:

```
你是一个[角色描述]。请严格按以下步骤操作：

## 步骤1: [描述]
[具体指令]

## 步骤2: [描述]
运行 /insights 命令，然后用 Read 工具读取最新的 report HTML。

## 步骤3: 输出报告
[输出格式要求]

### 风格要求
[约束条件]
```

## Verification

1. Run the script manually first: `zsh -l ./script.sh`
2. Check the log: `tail -f ~/.claude/logs/<script>.log`
3. Verify the notification arrived (Feishu/WeChat)
4. Only then install the crontab

## Example

See `self-reflection/daily-insights.sh` in this dotfiles repo for a complete
working example that:
- Scans today's memory files
- Runs `/insights`
- Generates a structured daily reflection report
- Sends via wechat-reminder

## Notes

- **macOS cron caveat**: On macOS, cron needs Full Disk Access permission.
  System Settings → Privacy & Security → Full Disk Access → add Terminal.app
- **Avoid :00 and :30 minutes** in cron schedules to reduce API fleet contention
- **Log everything**: cron's stdout/stderr can be lost; always write to a log file
- **Cross-platform `date`/`find`**: Use a temp reference file with `touch -t` (macOS BSD) or `touch -d` (Linux GNU) rather than `-newermt` for cross-platform `find -newer`
- **Idempotent install**: Write an `install.sh` that checks for existing crontab entries before adding, and supports `--uninstall` and `--status`
- **Prompt passing**: Use a temp file to build multi-line prompts rather than complex shell quoting

## References

- [Claude Code Commands](https://code.claude.com/docs/en/commands)
- User's `_claude_with_api` function in `common_shell_setup.sh`
- `claude-end-reminder.sh` hook for wechat-reminder integration pattern
