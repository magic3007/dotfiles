#!/usr/bin/env bash
# Register local Herdr plugins. Skips cleanly when herdr is not installed yet
# (the network phase re-runs the same link script after installing herdr).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/../herdr-plugin-link.sh"
