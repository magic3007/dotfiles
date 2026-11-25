#!/usr/bin/env bash
# Local state that the links alone cannot express. No network. ./install runs
# it after linking and sync.sh runs it on every 15-minute tick, so every step is
# idempotent and cheap. A failing step is reported and the others still run;
# the exit status is non-zero when any failed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
status=0

step() {
    printf -- '--> %s\n' "$1"
    shift
    "$@" || { printf 'warn  step failed: %s\n' "$*" >&2; status=1; }
}

sync_vim_plugins() {
    local dir
    for dir in sources_non_forked sources_forked; do
        rsync -a --delete "vim/vimrc/$dir/" "$HOME/.vim_plugins/$dir/" || return 1
    done
}

step "seed configs" bash scripts/seed-configs.sh
step "merge configs" python3 scripts/config-merge.py --quiet
step "skill views" python3 scripts/sync-skills.py
step "vim plugins" sync_vim_plugins
step "xmatrix daemon secrets" bash scripts/xmatrix-daemon-secrets.sh

exit "$status"
