#!/usr/bin/env bash
# Re-apply the tracked mcode config into ~/.minimax/config.yaml.
#
# mcode saves config.yaml by writing a .config-tmp-<hex> file and renaming it
# over the config path itself (the main writer does not resolve the realpath),
# so the file is machine-local and is NOT symlinked into the repo.
# scripts/mcode-config-sync.py merges the tracked keys from mcode/config.yaml
# and keeps everything the live file already holds.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec python3 "$REPO/scripts/mcode-config-sync.py"
