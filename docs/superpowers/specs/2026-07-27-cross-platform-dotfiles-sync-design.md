# Cross-Platform Dotfiles Auto-Sync Design

**Date**: 2026-07-27
**Status**: Draft
**Author**: Jing Mai

## Overview

Automatically sync cross-platform, non-sensitive dotfiles across multiple machines (macOS, Linux servers, remote dev machines) using a lightweight Dotbot-based configuration.

The entire dotfiles repository is public-safe — no secrets or sensitive content. The challenge is not about filtering secrets, but about **only deploying configuration files that work everywhere** while skipping platform-specific files (yabai, skhd, karabiner, iTerm2, etc.).

## Architecture

```
GitHub (public repo)
     │
     └─ cron/launchd/systemd timer (every 15 min)
          │
          ▼
     sync.sh ──→ git pull --ff-only
                    │
                    ▼
             git submodule update --init
                    │
                    ▼
             dotbot -c sync.conf.yaml
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
      macOS      Linux      Remote Dev
```

### Key Principles

- **White-list by design**: `sync.conf.yaml` explicitly lists only cross-platform files
- **Idempotent**: Running sync.sh multiple times is safe
- **Compatible with existing `./install`**: Full installation flow remains unchanged
- **Built on existing patterns**: `*_local` files for machine-specific overrides
- **Failure notification**: Reuses existing wechat-reminder for alerts

## Components

### 1. `sync.conf.yaml` — Cross-Platform Symlink Manifest

A Dotbot configuration file listing only local, cross-platform symlinks. Excludes:

| Category | Excluded | Reason |
|----------|----------|--------|
| macOS window management | yabai, skhd, karabiner | Linux-incompatible |
| macOS terminal emulators | iTerm2, Warp, Ghostty plist | macOS-only apps |
| macOS IDE paths | Antigravity, Cursor macOS paths | macOS-only apps |
| Fish shell | `fish/` directory | No longer maintained (per project constraint) |
| Network setup | oh-my-zsh, fzf, npm packages | One-time setup via `./install` |
| Platform packages | install-scripts/mac, install-scripts/linux | Handled by `./install` |
| Notification tools | wechat-reminder | Requires venv + file copy |
| Vim plugin sync | rsync commands | One-time setup |

**Full contents**: See the actual `sync.conf.yaml` file for the complete list of synced files.

- Shell config (zsh, bash, common_shell_setup)
- Git aliases (user info via `~/.gitconfig_local`)
- Editors (vim, neovim, ideavim)
- File managers (ranger, joshuto, yazi)
- CLI tools (lsd, starship, bat, tmux)
- Debugger (gdb)
- Package manager mirrors (conda, mamba, npm, pip, cargo)
- AI tool configs (claude, codex, gemini, opencode, kimi-code)
- Other cross-platform tools (ghostty, cmux)

### 2. `sync.sh` — Sync Script

```bash
#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/dotfiles-sync.log"

notify_failure() {
    local exit_code=$?
    HOSTNAME=$(hostname)
    ~/.wechat-reminder/wechat-reminder \
        "❌ dotfiles sync failed on $HOSTNAME (exit: $exit_code)" \
        "Check $LOG_FILE at $(date '+%Y-%m-%d %H:%M:%S')"
}
trap notify_failure ERR

echo "🔄 Updating dotfiles..." | tee "$LOG_FILE"
cd "$DOTFILES_DIR"

# Pull latest code
git pull --ff-only origin master >> "$LOG_FILE" 2>&1

# Initialize submodule (dotbot)
git submodule update --init >> "$LOG_FILE" 2>&1

# Apply cross-platform symlinks
"$DOTFILES_DIR/dotbot/bin/dotbot" -c "$DOTFILES_DIR/sync.conf.yaml" >> "$LOG_FILE" 2>&1
```

**Error handling**:

| Scenario | Behavior |
|----------|----------|
| Network unreachable | `git pull` fails, `trap` sends notification; next cron retries |
| Local git conflict | `--ff-only` prevents merge, `trap` notifies; requires manual fix |
| Symlink target exists as regular file | Dotbot `relink: true` handles gracefully |
| Missing parent directory | Dotbot `create: true` auto-creates |

### 3. Auto-Sync Scheduler (Every 15 Minutes)

#### macOS — LaunchAgent

A template plist file at `dotfiles/com.dotfiles.sync.plist` (the `--install` command substitutes the actual home path):

```xml
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__HOME__/dotfiles/sync.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/dotfiles-sync.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dotfiles-sync.log</string>
</dict>
</plist>
```

#### Linux — systemd Timer

`systemd/dotfiles-sync.service`:

```
[Unit]
Description=Sync dotfiles

[Service]
Type=oneshot
ExecStart=%h/dotfiles/sync.sh
```

`systemd/dotfiles-sync.timer`:

```
[Unit]
Description=Sync dotfiles every 15 minutes

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
```

### 4. Installation Command

`./sync.sh --install` sets up the scheduler automatically:

- **macOS**: Copies plist to `~/Library/LaunchAgents/` and runs `launchctl load`
- **Linux**: Copies systemd unit files and runs `systemctl --user enable --now`
- **Unknown**: Prints instructions for manual cron setup

## Security Model

- **No secrets in repo**: Whole repo is public-safe
- **`*_local` files**: Machine-specific overrides (`~/.gitconfig_local`, `~/.zsh_local`) are not tracked by git and not touched by sync
- **Sync is additive**: Only creates/updates symlinks; never removes non-synced local files

## Migration Path

1. Create `sync.conf.yaml` from existing `install.conf.yaml` (remove platform-specific entries)
2. Create `sync.sh`
3. Create systemd timer files
4. Run `./sync.sh --install` on each machine
5. Verify: `sync.sh` applies correctly, timer is active

## Future Considerations

- **Frequency tuning**: 15-minute interval is the default; can be adjusted per machine
- **Selective sync**: If needed later, add platform-aware filtering in `sync.sh`
- **Multi-branch**: If work machines need different configs, `sync.sh` can accept a branch parameter
