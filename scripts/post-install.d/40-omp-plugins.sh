#!/usr/bin/env bash
# Install the omp plugins declared in omp/plugins.txt.
#
# Why a hook and not a symlink: the plugins data root (~/.omp/plugins) is
# runtime state. `bun install` rewrites package.json and bun.lock, omp rewrites
# omp-plugins.lock.json in place, and node_modules holds hundreds of packages —
# none of it belongs in git. The repo therefore tracks only the list of specs
# (omp/plugins.txt) and lets omp's own installer materialize them.
#
# Only missing entries are installed. Re-running `omp plugin install` on an
# existing plugin is not a no-op: it re-resolves the package and resets the
# plugin's enabled features to the manifest defaults.
#
# Requires network (and `bun`) only when something is actually missing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIST="$REPO/omp/plugins.txt"

[[ -f $LIST ]] || exit 0

if ! command -v omp >/dev/null 2>&1; then
  printf 'warn  omp not on PATH — skipping plugin install\n' >&2
  exit 0
fi

# Runtime view of what is installed (npm + marketplace plugins).
installed="$(
  omp plugin list --json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for group in ("npm", "marketplace"):
    for entry in data.get(group) or []:
        if isinstance(entry, dict) and entry.get("name"):
            print(entry["name"])
' 2>/dev/null || true
)"

is_installed() {
  [[ -n $installed ]] && printf '%s\n' "$installed" | grep -qxF -- "$1"
}

status=0
while IFS= read -r line || [[ -n $line ]]; do
  spec="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  # Drop whole-line comments and inline comments introduced by whitespace. A `#`
  # inside a ref (`github:user/repo#main`) is not a comment.
  spec="$(printf '%s' "$spec" | sed -E 's/^#.*$//; s/[[:space:]]+#.*$//')"
  [[ -n $spec ]] || continue

  # spec → package name: drop a trailing feature bracket, the npm: prefix and a
  # version suffix (`pi-fff@1.2.3` → pi-fff, `@scope/pkg@1.2.3` → @scope/pkg).
  name="$(printf '%s' "$spec" | sed -E 's/\[[^]]*\]$//; s/^npm://; s/@[^@/]+$//')"

  if [[ ! $name =~ ^(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$ ]]; then
    printf 'warn  %s: not an npm spec (git/link plugins are not tracked here)\n' "$spec" >&2
    continue
  fi

  if is_installed "$name"; then
    printf 'ok    %s installed (left alone)\n' "$name"
    continue
  fi

  printf 'inst  %s <- %s\n' "$spec" "$(basename "$LIST")"
  if ! omp plugin install "$spec"; then
    printf 'warn  omp plugin install %s failed (offline?)\n' "$spec" >&2
    status=1
  fi
done < "$LIST"

exit "$status"
