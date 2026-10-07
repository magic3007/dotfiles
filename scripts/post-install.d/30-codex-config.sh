#!/usr/bin/env bash
# Regenerate ~/.codex/config.toml from the tracked shared config.
#
# Codex rewrites config.toml at runtime (hook trust, project trust, marketplace
# state), so the file is machine-local and is NOT symlinked into the repo.
# scripts/codex-config-sync.py re-applies the shared keys from
# codex/config.toml and keeps everything the live file already holds.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec python3 "$REPO/scripts/codex-config-sync.py"
