#!/usr/bin/env bash
# Run pi-herdr-agents subagents on omp instead of pi.
#
# The package hardcodes `pi` as the child harness: it passes `--session <file>`
# and `-e <hook>`, and waits for pi's `agent_settled` event. omp has none of
# those, so a bare install supervises pi children — which is useless on a
# machine whose models, roles and config live in omp.
#
# omp/patches/pi-herdr-agents-omp-runtime.patch switches the adapter to `omp`:
#   - child command `omp --hook ... --model ... --thinking ... '<task>'`
#   - child/pin-session.ts redirects omp's session writer to the path the
#     parent expects (omp has no `--session <file>` flag)
#   - auto-exit waits for `ctx.isIdle()` because omp emits no `agent_settled`
#   - the plugin skips registration inside a child (PI_SUBAGENT_ID), which
#     would otherwise let an omp child spawn grandchildren
#
# The package is not a git checkout, so scripts/apply-patches.sh cannot be
# reused; idempotency comes from a reverse dry run. A package version bump can
# make the patch stale — then this hook warns instead of half-applying it.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG="$HOME/.omp/plugins/node_modules/pi-herdr-agents"
PATCH="$REPO/omp/patches/pi-herdr-agents-omp-runtime.patch"
NAME="$(basename "$PATCH")"

if [[ ! -d $PKG ]]; then
	printf 'skip  pi-herdr-agents not installed\n'
	exit 0
fi

if [[ ! -f $PATCH ]]; then
	printf 'warn  patch missing: %s\n' "${PATCH#"$REPO"/}" >&2
	exit 1
fi

if patch -R -p1 -s -f --dry-run -d "$PKG" <"$PATCH" >/dev/null 2>&1; then
	printf 'ok    %s already applied\n' "$NAME"
	exit 0
fi

if ! patch -p1 -s -f --dry-run -d "$PKG" <"$PATCH" >/dev/null 2>&1; then
	printf 'warn  %s does not apply to %s (package version changed?) — children stay on pi\n' \
		"$NAME" "${PKG/#"$HOME"/\~}" >&2
	exit 1
fi

patch -p1 -s -f -d "$PKG" <"$PATCH"
installed="$(node -p 'require("'"$PKG"'/package.json").version' 2>/dev/null || true)"
printf 'patch %s (pi-herdr-agents %s children now run omp)\n' "$NAME" "${installed:-unknown}"
