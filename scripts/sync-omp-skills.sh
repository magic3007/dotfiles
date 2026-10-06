#!/usr/bin/env bash
# Rebuild ~/.omp/agent/skills so omp (Stencil) loads every skill exactly once.
#
# Usage: scripts/sync-omp-skills.sh [--dry-run]
#
# Why this exists
# ---------------
# omp discovers skills from ~/.omp/agent/skills (provider "native", user level,
# gated by skills.enablePiUser), ~/.agents/skills, and project dirs. It does NOT
# read ~/.pi/agent/skills, ~/.claude/skills or ~/.codex/skills, so
# ~/.omp/agent/skills must be a mirror or those skills are invisible to omp.
#
# Why the links are always DIRECTORY symlinks
# -------------------------------------------
# omp's skill loader (loadSkillsFromDir -> fp() in dist/cli.js) enumerates the
# skills dir with readdir(withFileTypes) and, for every entry that is a directory
# OR a symlink, only probes `<entry>/SKILL.md`:
#
#     for (const entry of dirents) {
#       if (!entry.isDirectory() && !entry.isSymbolicLink()) continue
#       const md = join(dir, entry.name, "SKILL.md")
#       if (existsSync(md)) push(read(md))
#     }
#
# It does not recurse and it does not read bare `*.md` files. So a file symlink
# such as `claudeception.md -> ~/.claude/skills/claudeception/SKILL.md` is
# silently dropped: the loader looks for `claudeception.md/SKILL.md`. That is why
# Pi (which does accept root-level `*.md` skills) could see those skills while
# omp could not. Hence: always symlink the skill *directory*, never the file.
#
# Linking a "container" skill dir (claudeception / storage-ops /
# weaver_harness_hub) is safe even though it has nested SKILL.md files: omp reads
# exactly one level, so only the container's own SKILL.md is picked up. The
# nested skills get their own top-level links from the scan below.
#
# Precedence per declared skill name:
#   1. ~/.agents/skills   (omp loads this natively; link there to avoid dupes)
#   2. ~/.claude/skills   (originals, scanned recursively)
#   3. ~/.codex/skills    (Codex-only skills, otherwise would be lost)
#
# Idempotent: safe to re-run. Never clobbers a real dir/file.

set -euo pipefail

OMP_SKILLS="$HOME/.omp/agent/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

python3 - "$OMP_SKILLS" "$AGENTS_SKILLS" "$CLAUDE_SKILLS" "$CODEX_SKILLS" "$DRY_RUN" <<'PY'
import os, re, sys

omp_dir, agents, claude, codex, dry_run = sys.argv[1:6]
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
        return None          # omp loads skills with requireDescription: true
    n = re.search(r"^name:\s*(.+)$", fm, re.M)
    if not n:
        return None
    name = n.group(1).strip().strip("\"'")
    return name or None

def scan(root, skip=()):
    """Yield (declared_name, skill_dir) for every SKILL.md below root."""
    if not os.path.isdir(root):
        return
    for dirpath, dirnames, filenames in os.walk(root):
        if "SKILL.md" not in filenames:
            continue
        rel = os.path.relpath(dirpath, root).split(os.sep)
        if any(part in skip for part in rel):
            continue
        name = declared_name(os.path.join(dirpath, "SKILL.md"))
        if name and "/" not in name and "\\" not in name:
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

os.makedirs(omp_dir, exist_ok=True)
created = updated = removed = 0

for name, (source, path) in sorted(chosen.items()):
    link = os.path.join(omp_dir, name)
    target = path          # keep the source-root-relative path, not realpath,
                           # so re-runs are no-ops and links stay readable

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

# Drop stale symlinks we own: broken ones, and `*.md` file symlinks left over
# from the Pi-style layout (omp can never load those -- see header).
valid = {os.path.join(omp_dir, name) for name in chosen}
for entry in os.listdir(omp_dir):
    full = os.path.join(omp_dir, entry)
    if not os.path.islink(full) or full in valid:
        continue
    unloadable = entry.endswith(".md") and os.path.isfile(os.path.realpath(full))
    if not os.path.exists(full) or unloadable:
        if not dry_run:
            os.unlink(full)
        removed += 1

print(f"skills resolved : {len(chosen)}")
print(f"created         : {created}")
print(f"updated         : {updated}")
print(f"stale removed   : {removed}")
print("(dry run, nothing written)" if dry_run else "done")
PY
