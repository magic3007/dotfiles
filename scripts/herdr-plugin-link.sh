#!/usr/bin/env bash
# Link the repo's local Herdr plugins into the current user's Herdr registry.
# Re-linking refreshes the manifest; a plugin the user disabled stays disabled.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ID="magic.wechat-notify"
PLUGIN_SRC="$DOTFILES_DIR/herdr/plugins/wechat-notify"

if ! command -v herdr >/dev/null 2>&1; then
    echo "herdr not installed; skipping plugin link"
    exit 0
fi

existing="$(herdr plugin list --json 2>/dev/null || true)"
state="$(
    printf '%s' "$existing" | python3 -c '
import json, os, sys

plugin_id, source = sys.argv[1], os.path.realpath(sys.argv[2])
try:
    payload = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    payload = {}
plugins = payload.get("result", {}).get("plugins", []) if isinstance(payload, dict) else []
for plugin in plugins:
    if plugin.get("plugin_id") != plugin_id:
        continue
    root = plugin.get("plugin_root")
    same_root = bool(root) and os.path.realpath(root) == source
    print("disabled" if same_root and not plugin.get("enabled", True) else "enabled")
    break
else:
    print("missing")
' "$PLUGIN_ID" "$PLUGIN_SRC"
)"

if ! herdr plugin link "$PLUGIN_SRC" >/dev/null; then
    echo "herdr plugin link failed for $PLUGIN_ID" >&2
    exit 1
fi

if [ "$state" = "disabled" ]; then
    herdr plugin disable "$PLUGIN_ID" >/dev/null
fi
