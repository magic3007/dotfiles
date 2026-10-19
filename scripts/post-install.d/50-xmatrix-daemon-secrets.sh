#!/usr/bin/env bash
# Keep the xmatrix daemon's environment in sync with the user's secrets file.
#
# xmatrix spawns agent runs from its systemd --user daemon, and the harness
# inherits the daemon's environment. Without this, credentials that only exist
# as environment variables are missing from every agent run (omp then sends the
# variable name as the API key → 401; codex env_key providers fail the same way).
#
# scripts/xmatrix-daemon-secrets.sh writes the drop-in and reloads systemd.
# Restart the daemon only when that cannot interrupt live agent runs.
set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
generator="$root/scripts/xmatrix-daemon-secrets.sh"
[ -x "$generator" ] || exit 0

runs="$HOME/.config/xmatrix/daemon-run-registry.json"
if [ -f "$runs" ] && grep -q '"pid"' "$runs" 2>/dev/null; then
    bash "$generator" || true
    echo "xmatrix: agent runs are live; drop-in written, daemon restart deferred" >&2
else
    bash "$generator" --restart || true
fi
