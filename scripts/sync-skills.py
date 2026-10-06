#!/usr/bin/env python3
"""Build every coding agent's user skills directory from this repo.

Source layout (repo)                 Generated view (home)          Read by
-----------------------------------  -----------------------------  -------------------------------
skills/<...>/SKILL.md   (shared)     ~/.agents/skills/<name>        Codex, Pi, omp, Cursor, Gemini
claude/skills/<...>     (Claude)     ~/.claude/skills/<name>        Claude Code (+ shared + externals)
codex/skills/<...>      (Codex)      ~/.codex/skills/<name>         Codex
pi/skills/<...>         (Pi)         ~/.pi/agent/skills/<name>      Pi
omp/skills/<...>        (omp)        ~/.omp/agent/skills/<name>     omp

Claude Code is the only harness that does not read ~/.agents/skills, so its view
also gets every shared skill and every external skill installed directly into
~/.agents/skills (e.g. lark-* from `npx skills add -g`).

Rules
-----
* Sources may nest skills inside bundles (tide/, scientific-agent-skills/...).
  Every SKILL.md is flattened to one top-level entry named by its frontmatter
  `name:` -- Claude Code and omp only scan one level deep.
* `examples/`, `plugins/`, `templates/`, hidden dirs and node_modules are never
  treated as skills.
* A skill dir that itself contains nested skills (storage-ops, claudeception,
  weaver_harness_hub) is exposed as a "shim": a real dir of per-child symlinks
  without the nested-skill subtrees (so recursive scanners -- Codex, Cursor --
  don't list those children twice) plus a copy of SKILL.md (Codex ignores a
  symlinked SKILL.md file).
* In claude/skills only, a top-level Claude plugin bundle without its own
  SKILL.md (`.claude-plugin/plugin.json`, e.g. codepp-harbor-task with hooks) is
  linked whole so Claude Code keeps loading it as a plugin.
* Views are real directories. Only entries this script owns are touched:
  symlinks into this repo / ~/.agents/skills / legacy mirrors, broken symlinks,
  and shim dirs. Real dirs written by tools (npx skills, Codex `.system`,
  Claude `synced`) are never modified.

Idempotent. Usage: scripts/sync-skills.py [--dry-run]
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HOME = Path.home()
AGENTS = HOME / ".agents" / "skills"

SOURCES = {
    "shared": REPO / "skills",
    "claude": REPO / "claude" / "skills",
    "codex": REPO / "codex" / "skills",
    "pi": REPO / "pi" / "skills",
    "omp": REPO / "omp" / "skills",
}
VIEWS = {
    "shared": AGENTS,
    "claude": HOME / ".claude" / "skills",
    "codex": HOME / ".codex" / "skills",
    "pi": HOME / ".pi" / "agent" / "skills",
    "omp": HOME / ".omp" / "agent" / "skills",
}
# Symlinks resolving under these roots were created by this script or by the
# old sync-pi-skills.sh / sync-omp-skills.sh mirrors, so they are ours to prune.
OWNED_ROOTS = [REPO, AGENTS, VIEWS["claude"], VIEWS["codex"]]
SKIP_DIRS = {"examples", "plugins", "templates", "node_modules", "__pycache__"}
SHIM_MARK = ".sync-skills-shim"
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")

DRY = False
warnings: list[str] = []


def warn(msg: str) -> None:
    warnings.append(msg)
    print(f"warning: {msg}", file=sys.stderr)


def act(msg: str) -> bool:
    print(("(dry-run) " if DRY else "") + msg)
    return not DRY


# --------------------------------------------------------------------------- discovery


def skill_name(skill_md: Path) -> str | None:
    try:
        text = skill_md.read_text(encoding="utf-8")
    except OSError as exc:
        warn(f"cannot read {skill_md}: {exc}")
        return None
    m = re.match(r"^---\r?\n(.*?)\r?\n---", text, re.DOTALL)
    if not m or not re.search(r"^description:\s*\S", m.group(1), re.MULTILINE):
        warn(f"skipping {skill_md}: frontmatter needs a description")
        return None
    n = re.search(r"^name:\s*(.+)$", m.group(1), re.MULTILINE)
    name = n.group(1).strip().strip("\"'") if n else skill_md.parent.name
    if not NAME_RE.match(name):
        warn(f"{skill_md}: name {name!r} is not lowercase-kebab (Agent Skills spec)")
    return name


def has_nested_skill(d: Path) -> bool:
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x != "node_modules"]
        if dirpath != str(d) and "SKILL.md" in filenames:
            return True
    return False


def discover(scope: str) -> dict[str, Path]:
    """Return {skill name: skill dir} for one source tree (shallowest wins)."""
    root = SOURCES[scope]
    found: dict[str, list[Path]] = {}
    if not root.is_dir():
        return {}
    for dirpath, dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        dirnames[:] = sorted(x for x in dirnames if not x.startswith(".") and x not in SKIP_DIRS)
        if (
            scope == "claude"
            and d.parent == root
            and "SKILL.md" not in filenames
            and (d / ".claude-plugin" / "plugin.json").is_file()
        ):
            found.setdefault(d.name, []).append(d)
            dirnames[:] = []
            continue
        if "SKILL.md" in filenames:
            name = skill_name(d / "SKILL.md")
            if name:
                found.setdefault(name, []).append(d)
    out = {}
    for name, dirs in found.items():
        dirs.sort(key=lambda p: (len(p.parts), str(p)))
        if len(dirs) > 1:
            warn(f"{scope}: skill {name!r} defined {len(dirs)}x, using {dirs[0]}")
        out[name] = dirs[0]
    return out


# --------------------------------------------------------------------------- placement


def plan_entry(src: Path, plugin_unit: bool = False) -> tuple[str, Path, dict[str, Path]]:
    """('link', src, {}) or ('shim', src, {child: target})."""
    if plugin_unit or not has_nested_skill(src):
        return ("link", src, {})
    children = {}
    for child in sorted(src.iterdir()):
        if child.name == ".claude-plugin":
            continue  # its manifest would point at the omitted nested skills
        if child.is_dir() and (has_nested_skill(child) or (child / "SKILL.md").exists()):
            continue
        children[child.name] = child
    return ("shim", src, children)


def is_owned_link(p: Path) -> bool:
    if not p.is_symlink():
        return False
    if not p.exists():
        return True  # broken
    target = Path(os.path.normpath(p.parent / os.readlink(p)))
    return any(target == r or r in target.parents for r in OWNED_ROOTS)


def is_shim(p: Path) -> bool:
    return p.is_dir() and not p.is_symlink() and (p / SHIM_MARK).is_file()


def shim_matches(p: Path, src: Path, children: dict[str, Path]) -> bool:
    if (p / SHIM_MARK).read_text().strip() != str(src):
        return False
    have = {c.name for c in p.iterdir() if c.name != SHIM_MARK}
    if have != set(children):
        return False
    for n, t in children.items():
        if n == "SKILL.md":
            if (p / n).is_symlink() or (p / n).read_bytes() != t.read_bytes():
                return False
        elif os.path.realpath(p / n) != os.path.realpath(t):
            return False
    return True


def remove(p: Path) -> None:
    if p.is_symlink():
        if act(f"unlink {p}"):
            p.unlink()
    elif is_shim(p):
        if act(f"remove shim {p}"):
            shutil.rmtree(p)


def place(view: Path, name: str, entry: tuple[str, Path, dict[str, Path]]) -> None:
    kind, src, children = entry
    dest = view / name
    if dest.is_symlink():
        if kind == "link" and os.path.realpath(dest) == os.path.realpath(src):
            return
        if not is_owned_link(dest):
            warn(f"{dest} is a foreign symlink; not replacing it with {src}")
            return
        remove(dest)
    elif is_shim(dest):
        if kind == "shim" and shim_matches(dest, src, children):
            return
        remove(dest)
    elif dest.exists():
        warn(f"{dest} is a real directory (not managed); {src} is shadowed")
        return
    if kind == "link":
        if act(f"link {dest} -> {src}"):
            dest.symlink_to(src)
        return
    if act(f"shim {dest} -> {src} ({len(children)} entries)"):
        dest.mkdir()
        (dest / SHIM_MARK).write_text(f"{src}\n")
        for n, t in children.items():
            # Codex follows symlinked skill folders but ignores a symlinked
            # SKILL.md file, so the shim carries a copy (refreshed on change).
            if n == "SKILL.md":
                shutil.copyfile(t, dest / n)
            else:
                (dest / n).symlink_to(t)


# --------------------------------------------------------------------------- views


def ensure_view(scope: str) -> Path | None:
    view = VIEWS[scope]
    if view.is_symlink():
        # Legacy: whole-dir link into the repo (old ~/.claude/skills, ~/.codex/skills).
        if act(f"replace whole-dir link {view} -> {os.readlink(view)} with a real dir"):
            view.unlink()
    if scope == "codex":
        legacy_system = SOURCES["codex"] / ".system"
        if legacy_system.is_dir() and not (view / ".system").exists():
            if act(f"move Codex runtime {legacy_system} -> {view / '.system'}"):
                view.mkdir(parents=True, exist_ok=True)
                shutil.move(str(legacy_system), view / ".system")
    if not view.exists():
        if not SOURCES[scope].is_dir() and scope != "claude":
            return None
        if act(f"mkdir {view}"):
            view.mkdir(parents=True)
    return view


def sync_view(scope: str, desired: dict[str, tuple[str, Path, dict[str, Path]]]) -> None:
    view = ensure_view(scope)
    if view is None or not view.exists():
        return
    for name in sorted(desired):
        place(view, name, desired[name])
    unmanaged = []
    for entry in sorted(view.iterdir()):
        if entry.name in desired or entry.name.startswith("."):
            continue
        if entry.is_symlink() or is_shim(entry):
            if is_shim(entry) or is_owned_link(entry):
                remove(entry)
        elif scope != "shared" and entry.name != "synced":
            unmanaged.append(entry.name)
    if unmanaged:
        print(f"note: {view} has unmanaged entries (move into the repo to track): {', '.join(unmanaged)}")


def external_skills(shared: dict[str, Path]) -> dict[str, Path]:
    """Skills installed straight into ~/.agents/skills (npx skills, manual)."""
    out = {}
    if not AGENTS.is_dir():
        return out
    for entry in sorted(AGENTS.iterdir()):
        if entry.name.startswith(".") or entry.name in shared:
            continue
        if is_owned_link(entry) or is_shim(entry):
            continue
        if (entry / "SKILL.md").is_file():
            out[entry.name] = entry
    return out


def main() -> int:
    global DRY
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="print actions without changing anything")
    DRY = ap.parse_args().dry_run

    found = {scope: discover(scope) for scope in SOURCES}
    shared = found["shared"]
    for scope in ("claude", "codex", "pi", "omp"):
        for name in sorted(set(found[scope]) & set(shared)):
            how = "overrides it in Claude Code" if scope == "claude" else "and both get listed"
            warn(f"{name!r} is in both skills/ and {scope}/skills/ ({how}); keep one")

    plans = {s: {n: plan_entry(d, plugin_unit=not (d / "SKILL.md").exists()) for n, d in found[s].items()} for s in SOURCES}

    sync_view("shared", plans["shared"])
    claude = {n: ("link", d, {}) for n, d in external_skills(shared).items()}
    claude.update(plans["shared"])
    claude.update(plans["claude"])
    sync_view("claude", claude)
    for scope in ("codex", "pi", "omp"):
        sync_view(scope, plans[scope])

    # Cursor reads ~/.claude/skills and ~/.agents/skills natively; the old
    # ~/.cursor/skills -> claude/skills link only duplicated them.
    cursor = HOME / ".cursor" / "skills"
    if is_owned_link(cursor):
        remove(cursor)

    counts = ", ".join(f"{s}={len(found[s])}" for s in SOURCES)
    print(f"skills: {counts}; claude view={len(claude)}; warnings={len(warnings)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
