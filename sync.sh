#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/dotfiles-sync.log"

# launchd (and systemd user units) start us with a minimal PATH, where python3 is
# /usr/bin/python3 — 3.9 on macOS, which has no tomllib — so every
# `python3 scripts/*.py` step below fails although the same steps work from an
# interactive shell. Put the user's own interpreters in front and keep whatever
# PATH we were handed as the tail.
export PATH="$HOME/.venv/bin:/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"

if ! python3 -c 'import tomllib' >/dev/null 2>&1; then
    echo "warn: $(command -v python3) ($(python3 -V 2>&1)) has no tomllib — the codex config merge needs 3.11+" \
        | tee -a "$LOG_FILE" >&2
fi

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

    git submodule update --init >> "$LOG_FILE" 2>&1

    "$DOTFILES_DIR/dotbot/bin/dotbot" -d "$DOTFILES_DIR" -c "$DOTFILES_DIR/install.conf.yaml" \
        --only clean create link >> "$LOG_FILE" 2>&1
    bash "$DOTFILES_DIR/scripts/apply.sh" >> "$LOG_FILE" 2>&1

    echo "✅ dotfiles synced successfully at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
}

install_launchagent() {
    if [[ "$(id -u)" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        echo "❌ Do not run with sudo. Use: ./sync.sh --install" >&2
        exit 1
    fi

    local plist_src="$DOTFILES_DIR/sync/com.dotfiles.sync.plist"
    local plist_dest="$HOME/Library/LaunchAgents/com.dotfiles.sync.plist"

    mkdir -p "$HOME/Library/LaunchAgents"
    sed "s|__DOTFILES__|$DOTFILES_DIR|g" "$plist_src" > "$plist_dest"

    # Unload first if already loaded, then reload
    launchctl unload "$plist_dest" 2>/dev/null || true
    launchctl load "$plist_dest"
    echo "✅ Installed LaunchAgent at $plist_dest"
}

install_systemd_timer() {
    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$unit_dir"

    sed "s|__DOTFILES__|$DOTFILES_DIR|g" "$DOTFILES_DIR/sync/dotfiles-sync.service" \
        > "$unit_dir/dotfiles-sync.service"
    cp "$DOTFILES_DIR/sync/dotfiles-sync.timer" "$unit_dir/"

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
