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

install_launchagent() {
    if [[ "$(id -u)" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        echo "❌ Do not run with sudo. Use: ./sync.sh --install" >&2
        exit 1
    fi

    local plist_src="$DOTFILES_DIR/com.dotfiles.sync.plist"
    local plist_dest="$HOME/Library/LaunchAgents/com.dotfiles.sync.plist"

    mkdir -p "$HOME/Library/LaunchAgents"
    sed "s|__HOME__|$HOME|g" "$plist_src" > "$plist_dest"

    # Unload first if already loaded, then reload
    launchctl unload "$plist_dest" 2>/dev/null || true
    launchctl load "$plist_dest"
    echo "✅ Installed LaunchAgent at $plist_dest"
}

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
