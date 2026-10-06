#!/usr/bin/env bash
# Apply patches to a checked-out dependency directory, idempotently.
#
# Usage: apply-patches.sh <target-dir> <patch> [<patch> ...]
#
# Used by the post-install hooks for vendored dependencies that are pinned to a
# revision too old to work on the local runtime (see post-install.d/). The
# target must be a git checkout, which is what makes idempotency cheap: a patch
# that is already applied passes the reverse check and is skipped.
set -uo pipefail

if [[ $# -lt 2 ]]; then
  printf 'usage: %s <target-dir> <patch> [<patch> ...]\n' "$(basename "$0")" >&2
  exit 2
fi

dir="$1"
shift
status=0

if [[ ! -d $dir/.git ]]; then
  printf 'warn  not a git checkout: %s\n' "$dir" >&2
  exit 0
fi

for patch in "$@"; do
  name="$(basename "$patch")"
  if [[ ! -f $patch ]]; then
    printf 'warn  patch missing: %s\n' "$patch" >&2
    status=1
  elif git -C "$dir" apply --reverse --check "$patch" 2>/dev/null; then
    printf 'ok    %s already applied\n' "$name"
  elif git -C "$dir" apply --check "$patch" 2>/dev/null; then
    git -C "$dir" apply "$patch"
    printf 'patch %s\n' "$name"
  else
    printf 'warn  %s does not apply cleanly — inspect %s\n' "$name" "$dir" >&2
    status=1
  fi
done

exit "$status"
