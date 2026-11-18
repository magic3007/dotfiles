#!/usr/bin/env bash
# Negative control for private_skills_ignored.
#
# The check needs real git state (tracked vs ignored), which a static fixture
# inside this repository cannot express: every file committed here is tracked.
# So build a throwaway checkout holding one untracked, unignored skill and
# assert the check rejects it.
#
# Exit 0 means the check failed as it should.
set -uo pipefail

CHECK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/checks/private_skills_ignored.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
mkdir -p "$tmp/skills/leaked-internal-skill"
printf -- '---\nname: leaked-internal-skill\ndescription: internal\n---\n' \
    > "$tmp/skills/leaked-internal-skill/SKILL.md"

! python3 "$CHECK" --root "$tmp"
