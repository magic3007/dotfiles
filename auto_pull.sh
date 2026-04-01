#!/bin/bash
# Auto-pull dotfiles from remote and run install
# Usage: ./auto_pull.sh [--check-cron]

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CRON_FILE="$HOME/.claude/scheduled_tasks.json"
SCRIPT_NAME="$(basename "$0")"
PATTERN="auto_pull"

check_cron_status() {
    if [ ! -f "$CRON_FILE" ]; then
        echo "No scheduled tasks found."
        return
    fi

    local found=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "\"prompt\".*auto_pull"; then
            found=1
            local id=$(echo "$line" | grep -o '"id": "[^"]*"' | cut -d'"' -f4)
            local cron=$(echo "$line" | grep -o '"cron": "[^"]*"' | cut -d'"' -f4)
            local recurring=$(echo "$line" | grep -o '"recurring": [^,]*' | cut -d':' -f2 | tr -d ' ')
            echo "Cron job found:"
            echo "  ID:      $id"
            echo "  Cron:    $cron"
            echo "  Recurring: $recurring"
        fi
    done < "$CRON_FILE"

    if [ $found -eq 0 ]; then
        echo "No auto_pull cron job found."
    fi
}

if [ "$1" = "--check-cron" ]; then
    check_cron_status
    exit 0
fi

cd "$DOTFILES_DIR"

echo "=== Auto-pull dotfiles at $(date) ==="

# Fetch and check for updates
git fetch origin

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "Already up-to-date."
    exit 0
fi

echo "Updates available! Pulling..."
git pull
./install
echo "=== Done at $(date) ==="
