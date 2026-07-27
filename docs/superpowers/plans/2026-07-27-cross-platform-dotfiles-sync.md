# Cross-Platform Dotfiles Auto-Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement automatic 15-minute sync of cross-platform dotfiles across macOS and Linux machines using Dotbot + cron/launchd/systemd.

**Architecture:** Extract cross-platform symlinks from `install.conf.yaml` into a dedicated `sync.conf.yaml`. Create a `sync.sh` script that `git pull --ff-only` + `dotbot -c sync.conf.yaml`. Add scheduler integration via `sync.sh --install` (macOS LaunchAgent, Linux systemd timer). Error notifications via wechat-reminder.

**Tech Stack:** Dotbot, bash, launchd (macOS), systemd (Linux), wechat-reminder

---

### File Structure

| File | Status | Purpose |
|------|--------|---------|
| `sync.conf.yaml` | **Create** | Dotbot config: cross-platform symlinks only |
| `sync.sh` | **Create** | Pull + sync script with scheduler install |
| `com.dotfiles.sync.plist` | **Create** | macOS LaunchAgent template (15-min interval) |
| `systemd/dotfiles-sync.service` | **Create** | Linux systemd oneshot service |
| `systemd/dotfiles-sync.timer` | **Create** | Linux systemd timer (15-min) |
| `install.conf.yaml` | **Modify** | Add symlinks for new created files |
| `CLAUDE.md` | **Modify** | Document new sync system |
| `README.md` | **Modify** | Document sync usage |

---

### Task 1: Create `sync.conf.yaml`

**Files:**
- Create: `sync.conf.yaml`

Extract the cross-platform, non-sensitive symlinks from `install.conf.yaml` into a new Dotbot config. Exclude: yabai, skhd, karabiner, iTerm2, Warp, Antigravity, Cursor macOS paths, VSCode, fish, wechat-reminder, vim plugin rsync, oh-my-zsh/fzf/nvm install, platform install scripts.

**Expected output:** A Dotbot config that runs `clean` + `create` dirs + `link` for ~30 entries, completing in <1s on subsequent runs.

- [ ] **Step 1: Create the file**

```bash
touch sync.conf.yaml
```

- [ ] **Step 2: Write the Dotbot config header + defaults + clean**

```yaml
# =============================================================================
# sync.conf.yaml — Cross-platform dotfiles sync (no network required)
# Used by sync.sh for automatic 15-min sync across all machines
# =============================================================================

- defaults:
    link:
        create: true
        relink: true

- clean: ["~"]

- create:
    - ~/.vim/undo-history
    - ~/.wastebasket
    - ~/.config/ghostty
    - ~/.config/cmux
    - ~/.config/bat

- link:
```

- [ ] **Step 3: Add shell + git + tmux symlinks**

```yaml
    # ---- Shell ----
    ~/.zshenv: oh-my-zsh/zshenv
    ~/.zshrc: oh-my-zsh/zshrc
    ~/.zshrc.d: oh-my-zsh/zshrc.d
    ~/.bashrc: bash/bashrc
    ~/.common_shell_setup.sh: common_shell_setup.sh

    # ---- Git ----
    ~/.gitconfig: git/gitconfig

    # ---- Terminal multiplexer ----
    ~/.tmux.conf: tmux.conf
```

- [ ] **Step 4: Add editor symlinks**

```yaml
    # ---- Editors ----
    ~/.vimrc: vim/vimrc/vimrc
    ~/.vim_runtime: vim/vimrc
    ~/.ideavimrc: ideavimrc
    ~/.config/nvim: neovim/nvim-basic-ide
```

- [ ] **Step 5: Add file manager symlinks**

```yaml
    # ---- File managers ----
    ~/.config/ranger: ranger
    ~/.config/joshuto: joshuto
    ~/.config/yazi: yazi
```

- [ ] **Step 6: Add CLI tools + debugger symlinks**

```yaml
    # ---- CLI tools ----
    ~/.config/lsd: lsd
    ~/.config/starship.toml: starship/starship.toml
    ~/.config/bat/config: bat/config

    # ---- Debugger ----
    ~/.gdb: gdb
    ~/.gdbinit: gdb/gdbinit
```

- [ ] **Step 7: Add package manager mirror symlinks**

```yaml
    # ---- Package managers (CN mirrors) ----
    ~/.condarc: condarc
    ~/.mambarc: mambarc
    ~/.npmrc: npmrc
    ~/.config/pip/pip.conf: pip.conf
    ~/.cargo/config.toml: cargo/config.toml

    # ---- Language config ----
    ~/.Rprofile: Rprofile
```

- [ ] **Step 8: Add AI tool config symlinks**

```yaml
    # ---- AI tools ----
    ~/.claude/settings.json: claude/settings.json
    ~/.claude/config.json: claude/config.json
    ~/.claude/skills: claude/skills
    ~/.claude/commands: claude/commands
    ~/.claude/hooks: claude/hooks
    ~/.claude/scripts: claude/scripts
    ~/.codex/config.json: codex/config.json
    ~/.codex/settings.json: codex/settings.json
    ~/.codex/codex_env.sh: codex/codex_env.sh
    ~/.codex/skills: codex/skills
    ~/.gemini/settings.json: gemini/settings.json
    ~/.gemini/skills: gemini/skills
    ~/.pi/agent/settings.json: pi/settings.json
    ~/.pi/agent/models.json: pi/models.json
    ~/.chatgpt.sh: chatgpt/chatgpt.sh
    ~/.config/opencode/opencode.json: opencode/opencode.json
    ~/.config/opencode/package.json: opencode/package.json
    ~/.kimi-code/config.toml: kimi-code/config.toml
    ~/.local/bin/yolo: scripts/yolo-generic.sh
    ~/.cursor/skills: claude/skills
```

- [ ] **Step 9: Add other cross-platform tool symlinks**

```yaml
    # ---- Ghostty ----
    ~/.config/ghostty/config: ghostty/config

    # ---- cmux ----
    ~/.config/cmux/cmux.json: cmux/cmux.json
```

- [ ] **Step 10: Verify the config is valid YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('sync.conf.yaml')); print('Valid YAML')"
```

Expected output: `Valid YAML`

- [ ] **Step 11: Commit**

```bash
git add sync.conf.yaml
git commit -m "feat: add cross-platform sync manifest (sync.conf.yaml)"
```

---

### Task 2: Create `sync.sh`

**Files:**
- Create: `sync.sh`

The sync script with three modes:
- Default: `git pull --ff-only` + `git submodule update --init` + `dotbot -c sync.conf.yaml`
- `sync.sh --install`: Install scheduler (LaunchAgent on macOS, systemd on Linux)
- Error notification via wechat-reminder `trap`

- [ ] **Step 1: Create the file**

```bash
touch sync.sh && chmod +x sync.sh
```

- [ ] **Step 2: Write the script header and failure trap**

```bash
#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/dotfiles-sync.log"

notify_failure() {
    local exit_code=$?
    HOSTNAME=$(hostname)
    if command -v ~/.wechat-reminder/wechat-reminder &>/dev/null; then
        ~/.wechat-reminder/wechat-reminder \
            "❌ dotfiles sync failed on $HOSTNAME (exit: $exit_code)" \
            "Log: $LOG_FILE at $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
    fi
}
trap notify_failure ERR
```

- [ ] **Step 3: Write the sync function**

```bash
do_sync() {
    echo "🔄 Updating dotfiles..." | tee "$LOG_FILE"
    cd "$DOTFILES_DIR"

    # Pull latest code (fast-forward only to prevent accidental merges)
    git pull --ff-only origin master >> "$LOG_FILE" 2>&1

    # Initialize submodule (dotbot)
    git submodule update --init >> "$LOG_FILE" 2>&1

    # Apply cross-platform symlinks
    "$DOTFILES_DIR/dotbot/bin/dotbot" -c "$DOTFILES_DIR/sync.conf.yaml" >> "$LOG_FILE" 2>&1

    echo "✅ dotfiles synced successfully at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
}
```

- [ ] **Step 4: Write the scheduler install function (macOS)**

```bash
install_launchagent() {
    local plist_src="$DOTFILES_DIR/com.dotfiles.sync.plist"
    local plist_dest="$HOME/Library/LaunchAgents/com.dotfiles.sync.plist"

    mkdir -p "$HOME/Library/LaunchAgents"
    sed "s|__HOME__|$HOME|g" "$plist_src" > "$plist_dest"
    launchctl load "$plist_dest"
    echo "✅ Installed LaunchAgent at $plist_dest"
}
```

- [ ] **Step 5: Write the scheduler install function (Linux)**

```bash
install_systemd_timer() {
    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$unit_dir"

    cp "$DOTFILES_DIR/systemd/dotfiles-sync.service" "$unit_dir/"
    cp "$DOTFILES_DIR/systemd/dotfiles-sync.timer" "$unit_dir/"

    # %h expands to $HOME automatically in systemd user units
    systemctl --user daemon-reload
    systemctl --user enable --now dotfiles-sync.timer
    echo "✅ Installed systemd timer (enabled and started)"
}
```

- [ ] **Step 6: Write the main dispatch logic**

```bash
main() {
    case "${1:-}" in
        --install)
            case "$(uname)" in
                Darwin)
                    install_launchagent
                    ;;
                Linux)
                    install_systemd_timer
                    ;;
                *)
                    echo "Unknown OS. Manual cron setup:"
                    echo "  */15 * * * * $DOTFILES_DIR/sync.sh"
                    exit 1
                    ;;
            esac
            ;;
        --help|-h)
            echo "Usage: sync.sh [--install|--help]"
            echo "  (no args)   Sync dotfiles (git pull + dotbot)"
            echo "  --install   Install auto-sync scheduler (15-min interval)"
            ;;
        *)
            do_sync
            ;;
    esac
}

main "$@"
```

- [ ] **Step 7: Assemble the complete script**

Combine all the above into `sync.sh`. Verify syntax:

```bash
bash -n sync.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 8: Commit**

```bash
chmod +x sync.sh
git add sync.sh
git commit -m "feat: add sync.sh for cross-platform dotfiles auto-sync"
```

---

### Task 3: Create macOS LaunchAgent template

**Files:**
- Create: `com.dotfiles.sync.plist`

- [ ] **Step 1: Write the plist template**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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

`__HOME__` is a placeholder; `sync.sh --install` replaces it with the actual home path via `sed`.

- [ ] **Step 2: Verify XML syntax**

```bash
plutil -lint com.dotfiles.sync.plist
```

Expected output: `OK`

- [ ] **Step 3: Commit**

```bash
git add com.dotfiles.sync.plist
git commit -m "feat: add LaunchAgent template for macOS auto-sync"
```

---

### Task 4: Create Linux systemd timer files

**Files:**
- Create: `systemd/dotfiles-sync.service`
- Create: `systemd/dotfiles-sync.timer`

- [ ] **Step 1: Create systemd directory**

```bash
mkdir -p systemd
```

- [ ] **Step 2: Write the service unit**

```ini
[Unit]
Description=Sync dotfiles (git pull + dotbot cross-platform configs)

[Service]
Type=oneshot
ExecStart=%h/dotfiles/sync.sh
```

`%h` expands to the user's home directory in systemd user units.

- [ ] **Step 3: Write the timer unit**

```ini
[Unit]
Description=Sync dotfiles every 15 minutes

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
```

- [ ] **Step 4: Verify the files exist**

```bash
ls -la systemd/
```

Expected: `dotfiles-sync.service` and `dotfiles-sync.timer`

- [ ] **Step 5: Commit**

```bash
git add systemd/
git commit -m "feat: add systemd timer for Linux auto-sync"
```

---

### Task 5: Install scheduler on macOS

- [ ] **Step 1: Run `--install` on this machine**

```bash
cd ~/dotfiles && ./sync.sh --install
```

Expected: "Installed LaunchAgent at ..." and no errors.

- [ ] **Step 2: Verify the LaunchAgent is loaded**

```bash
launchctl list | grep dotfiles
```

Expected output: a line with `com.dotfiles.sync` in it.

- [ ] **Step 3: Verify the plist has the correct home path**

```bash
plutil -p ~/Library/LaunchAgents/com.dotfiles.sync.plist | grep ProgramArguments
```

Expected: the array contains the correct path (your actual home, not `__HOME__`).

- [ ] **Step 4: Do a trial run**

```bash
./sync.sh
```

Expected: symlinks created, no errors.

---

### Task 6: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Add sync system documentation to CLAUDE.md**

Add a section after the existing "Architecture" content:

```markdown
### Auto-Sync System

`sync.sh` provides automatic 15-min cross-platform sync:

- **`./sync.sh`** — Git pull + apply only cross-platform symlinks (via `sync.conf.yaml`)
- **`./sync.sh --install`** — Install scheduler: macOS LaunchAgent or Linux systemd timer
- **Error notification** — On failure, sends alert via wechat-reminder (Feishu/WeChat)

`sync.conf.yaml` is a Dotbot config containing only cross-platform, non-sensitive symlinks.
It excludes macOS-specific tools (yabai, skhd, karabiner, iTerm2, Warp),
network install steps (oh-my-zsh, Homebrew, npm), and platform install scripts.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document auto-sync system in CLAUDE.md"
```

- [ ] **Step 3: Update README.md** (if there's a sync/install section suitable for it)

Locate the README section that describes installation and add the sync.sh usage.

---

## Self-Review Checklist

1. **Spec coverage**: Design spec covers sync.conf.yaml, sync.sh, scheduler install, and failure notification. Plan covers all four with Tasks 1-5.
2. **Placeholder scan**: No "TBD", "TODO", or incomplete code blocks.
3. **Type consistency**: All file paths and script references are consistent across tasks.
4. **Scope**: Single subsystem — dotfile sync. No need for further decomposition.
