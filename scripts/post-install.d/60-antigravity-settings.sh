#!/usr/bin/env bash
# Re-apply the tracked Antigravity CLI settings into
# ~/.gemini/antigravity-cli/settings.json.
#
# agy rewrites settings.json in place (config edits, workspace trust, granted
# permissions), so the file is machine-local and is NOT symlinked into the
# repo. scripts/antigravity-settings-sync.py merges the tracked keys from
# antigravity/cli-settings.json and keeps everything else the live file holds.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ -d $HOME/.gemini/antigravity-cli ]] || exit 0

exec python3 "$REPO/scripts/antigravity-settings-sync.py" "$@"
