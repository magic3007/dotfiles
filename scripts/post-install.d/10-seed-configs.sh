#!/usr/bin/env bash
# Seed config files for tools that rewrite their own config in place.
#
# Why not a symlink: such tools write a temporary file and rename it over the
# target, which replaces the symlink with a regular file. The next dotbot run
# then fails with
#   "~/.kimi-code/config.toml already exists but is a regular file or directory"
# and dotbot exits 1 for the whole run. Verified against the kimi CLI 0.26.0:
# after `kimi provider remove ...` the path went from symbolic link (inode
# 1708625) to regular file (inode 1708626) while the symlink target was never
# written.
#
# So the repo keeps a reference copy and copies it in only when the target is
# missing. An existing file is never touched, which also means the tool's own
# edits (model choice, thinking effort) survive.
#
# The pi-fff entry is the same idea applied to plugin feature state: pi-fff
# writes ~/.omp/agent/extensions/pi-fff.json whenever /fff-features toggles a
# feature, so the repo seeds a copy with its incompatible `autocomplete` feature
# (which breaks omp's `@` completion) left out — see omp/README.md, "Plugins".
#
# Add one "repo-path:destination" pair per line. Both sides are expanded; the
# destination's parent directory is created when seeding.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SEEDS=(
  "kimi-code/config.toml:$HOME/.kimi-code/config.toml"
  "omp/pi-fff-features.json:$HOME/.omp/agent/extensions/pi-fff.json"
)

for entry in "${SEEDS[@]}"; do
  src="$REPO/${entry%%:*}"
  dest="${entry#*:}"

  if [[ ! -f $src ]]; then
    printf 'warn  seed source missing: %s\n' "${src#"$REPO"/}" >&2
    continue
  fi

  if [[ -e $dest ]]; then
    printf 'ok    %s exists (left alone)\n' "${dest/#"$HOME"/\~}"
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  printf 'seed  %s <- %s\n' "${dest/#"$HOME"/\~}" "${src#"$REPO"/}"
done
