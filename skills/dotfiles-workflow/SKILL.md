---
name: dotfiles-workflow
description: "Working in the dotfiles repository: adding or changing a config, a skill, a shell wrapper or a harness setting; deciding between link, merge and seed; recording a correction as a check; verifying a change before commit. Use when the working directory is a dotfiles checkout managed by Dotbot with .repo-std/gate.sh."
---

# dotfiles workflow

The repository documents itself. This skill exists so an agent reaches the right
document before editing, and runs the gate before claiming done.

## Order of operations

1. **Read `docs/REPO_GUIDE.md` first.** It holds the rules, the single-source-of-truth
   table, and a change-path table keyed by what you are about to do. Nothing is
   duplicated elsewhere, so skipping it means guessing.
2. Make the change at the entry point that table names.
3. Run the gate. It is the acceptance criterion:

   ```bash
   bash .repo-std/gate.sh
   ```

## The one decision that is easy to get wrong

A new config file is delivered in one of three ways — **link**, **merge**, or
**seed** — and the choice depends on whether the owning tool rewrites the file
itself. Choosing link for a self-rewriting tool corrupts the repository and
breaks every later `./install`. `docs/REPO_GUIDE.md` §2 has the table and the
list of tools already classified.

A link always goes into **both** `install.conf.yaml` and `sync.conf.yaml`.

## When the user corrects you

Do not add a line to a rules file. Write a check that fails, under
`.repo-std/checks/`, with a violating fixture under
`.repo-std/checks/fixtures/<name>/`, and register it in
`.repo-std/corrections.yml`. Four steps, spelled out in `docs/REPO_GUIDE.md` §5.

Then prove the check actually guards something:

```bash
bash .repo-std/gate.sh --prove
```

That runs every check against its violating fixture and fails unless each check
reports a `FAIL  ` line there. A guard that has never failed is a guard nobody
tested.

## Commands

```bash
bash .repo-std/gate.sh              # every check, against the repository
bash .repo-std/gate.sh --prove      # negative control
python3 scripts/sync-skills.py --dry-run
./install --only link               # idempotent; no --dry-run exists
```

## Things that are not true of other repositories

- There is no dry-run flag; the pinned Dotbot rejects it.
- `./install` and `sync.sh` read different config files.
- Harness config under `~/` is often generated or merged — editing the live file
  is reverted within 15 minutes. Edit the tracked source.
- The repository is public; credentials are always a reference, never a literal,
  and a skill directory is private until `.gitignore` allowlists it.
