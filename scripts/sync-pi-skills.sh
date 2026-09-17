#!/usr/bin/env bash
# Rebuild ~/.pi/agent/skills so Pi loads every skill exactly once.
#
# Why this exists
# ---------------
# Pi discovers skills from several locations. Besides ~/.pi/agent/skills it also
# auto-loads ~/.agents/skills (not disableable from settings.json). Loading
# ~/.claude/skills and ~/.codex/skills directly from settings.json caused:
#   * 231 "name collision" warnings  (codex/skills is a generated copy of claude/skills)
#   * 2  "description is required"   (AGENTS.md / README.md at codex/skills root)
#
# Instead we make ~/.pi/agent/skills the single source of truth by symlinking
# every real skill into it, preferring the Claude original over the Codex copy.
#
# Precedence per skill name:
#   1. ~/.agents/skills            (Pi auto-loads this; link there to avoid dupes)
#   2. ~/.claude/skills            (originals, scanned recursively)
#   3. ~/.codex/skills             (Codex-only skills, otherwise would be lost)
#
# Idempotent: safe to re-run. Never deletes non-symlink entries.
# Usage: scripts/sync-pi-skills.sh [--dry-run]

set -euo pipefail

PI_SKILLS="$HOME/.pi/agent/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# Skill dirs that hold nested SKILL.md files. Linking the directory wholesale
# would recursively pull in children that also exist as top-level skills,
# recreating collisions; so only their own SKILL.md is linked (as a root .md
# skill, which Pi treats as a single non-recursive skill).
# NOTE: matched by *directory path*, not declared name (weaver_harness_hub
# declares `name: hub`, but its directory is what must not be recursed into).
CONTAINERS="$CLAUDE_SKILLS/claudeception $CLAUDE_SKILLS/storage-ops $CLAUDE_SKILLS/weaver_harness_hub"

python3 - "$PI_SKILLS" "$AGENTS_SKILLS" "$CLAUDE_SKILLS" "$CODEX_SKILLS" "$DRY_RUN" "$CONTAINERS" <<'PY'
import os, re, sys

pi_dir, agents, claude, codex, dry_run, containers = sys.argv[1:7]
containers = {os.path.realpath(p) for p in containers.split()}
dry_run = dry_run == "1"

def declared_name(skill_md):
    """Read `name:` from SKILL.md frontmatter; None if unusable."""
    try:
        text = open(skill_md, encoding="utf-8").read()
    except OSError:
        return None
    m = re.match(r"^---\r?\n(.*?)\r?\n---", text, re.DOTALL)
    if not m:
        return None
    fm = m.group(1)
    if not re.search(r"^description:\s*\S", fm, re.M) and \
       not re.search(r"^description:\s*[|>]", fm, re.M):
        return None          # Pi refuses to load skills without a description
    n = re.search(r"^name:\s*(.+)$", fm, re.M)
    if not n:
        return None
    return n.group(1).strip().strip("\"'")

def scan(root, skip=()):
    """Yield (declared_name, skill_dir) for every SKILL.md below root."""
    if not os.path.isdir(root):
        return
    for dirpath, dirnames, filenames in os.walk(root):
        if "SKILL.md" not in filenames:
            continue
        if any(part in skip for part in os.path.relpath(dirpath, root).split(os.sep)):
            continue
        name = declared_name(os.path.join(dirpath, "SKILL.md"))
        if name:
            yield name, dirpath

# Build the winner for each declared skill name, in precedence order.
chosen = {}
for source, root, skip in (
    ("agents", agents, ()),
    ("claude", claude, (".system", "examples", "plugins")),
    ("codex", codex, ()),
):
    for name, path in sorted(scan(root, skip)):
        chosen.setdefault(name, (source, path))

os.makedirs(pi_dir, exist_ok=True)
created = updated = removed = 0

def is_container(path):
    return os.path.realpath(path) in containers

for name, (source, path) in sorted(chosen.items()):
    link = os.path.join(pi_dir, name)
    if is_container(path):
        # link only SKILL.md -> single non-recursive skill
        target, link = os.path.join(path, "SKILL.md"), link + ".md"
    else:
        target = path

    if os.path.islink(link):
        if os.readlink(link) == target:
            continue
        if not dry_run:
            os.unlink(link)
            os.symlink(target, link)
        updated += 1
        continue
    if os.path.exists(link):
        continue                     # real dir/file: never clobber
    if not dry_run:
        os.symlink(target, link)
    created += 1

# Drop stale symlinks we previously created: broken links, and links that
# resolve to a container SKILL.md but are not the canonical *.md link name
# (e.g. a leftover weaver_harness_hub.md when the canonical name is hub.md).
valid = set()
for name, (_, path) in chosen.items():
    valid.add(os.path.join(pi_dir, name + ".md" if is_container(path) else name))
container_mds = {
    os.path.realpath(os.path.join(path, "SKILL.md"))
    for _, path in chosen.values() if is_container(path)
}
for entry in os.listdir(pi_dir):
    full = os.path.join(pi_dir, entry)
    if not os.path.islink(full) or full in valid:
        continue
    broken = not os.path.exists(full)
    stray_container_md = os.path.realpath(full) in container_mds
    if broken or stray_container_md:
        if not dry_run:
            os.unlink(full)
        removed += 1

print(f"skills resolved : {len(chosen)}")
print(f"created         : {created}")
print(f"updated         : {updated}")
print(f"stale removed   : {removed}")
print("(dry run, nothing written)" if dry_run else "done")
PY
