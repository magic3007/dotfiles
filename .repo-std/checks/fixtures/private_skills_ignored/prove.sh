#!/usr/bin/env bash
# Fixture for private_skills_ignored.
#
# The check needs real git state (tracked vs ignored), which a static tree inside
# this repository cannot express: every file committed here is tracked. So build
# a throwaway checkout holding both broken states and run the check on it:
# an untracked skill that is not ignored, and a tracked skill that is ignored.
set -uo pipefail

CHECK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/private_skills_ignored.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
for name in leaked-internal-skill published-but-ignored; do
    mkdir -p "$tmp/skills/$name"
    printf -- '---\nname: %s\ndescription: x\n---\n' "$name" > "$tmp/skills/$name/SKILL.md"
done
git -C "$tmp" add skills/published-but-ignored
printf 'skills/published-but-ignored/\n' > "$tmp/.gitignore"

python3 "$CHECK" --root "$tmp"
