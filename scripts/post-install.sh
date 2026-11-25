#!/usr/bin/env bash
# Post-install fixups.
#
# Everything that must happen after the symlinks exist but that dotbot cannot
# express: seeding files that their owning tool rewrites, patching/repinning
# vendored dependencies, and similar runtime repairs.
#
# Each hook in post-install.d/ is idempotent and standalone; one failing hook
# must not stop the others, so failures are reported and the exit status is
# non-zero at the end (install.conf.yaml ignores it on purpose).
#
# A hook can also be run directly. The 15-minute sync (sync.conf.yaml `shell:`)
# runs the seed hook and calls the merge scripts itself, skipping the rest.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0

for hook in "$DIR"/post-install.d/*.sh; do
  [[ -f $hook ]] || continue
  printf -- '--> %s\n' "$(basename "$hook")"
  if ! bash "$hook"; then
    printf 'warn  %s failed — continuing\n' "$(basename "$hook")" >&2
    status=1
  fi
done

exit "$status"
