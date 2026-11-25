---
name: scan-commit
description: Automatically scan the repository for unstaged/untracked changes, group them into logical commits using hunk-level analysis, stage and commit them following Conventional Commits.
---

# Scan Commit

Scan the entire working tree for pending changes — unstaged modifications, untracked files, and (with a warning) already-staged changes — analyze them into logical groups at the hunk level, then stage and commit each group with well-structured messages following [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

This extends the smart-commit workflow by adding the scanning and staging phases. It handles the common case where a developer has been working on multiple concerns and hasn't staged anything yet.

## Usage

Invoke with `/scan-commit` or when the task matches.

**Arguments:**

- `--dry-run`: Only show the proposed commit plan without executing

## Workflow

### Step 1: Scan All Changes

```bash
# Unstaged modifications to tracked files
git diff --no-color

# Untracked new files
git status --porcelain

# Already-staged changes (warn if present)
git diff --cached --stat
```

Collect three categories of changes:

| Category | Command | Description |
|----------|---------|-------------|
| **Modified (unstaged)** | `git diff --no-color` | Changes to tracked files not yet staged |
| **Untracked** | `git status --porcelain` | New files git doesn't know about |
| **Staged** | `git diff --cached --stat` | Already staged (warn, include in analysis) |

**If no changes exist at all**, stop and inform the user.

**If there are already-staged changes**, warn the user. Include them in the analysis but note they are already staged — they will be committed as-is (no hunk splitting on already-staged content).

### Step 2: Read and Understand All Changes

For each changed file, understand:
- What was added, modified, or deleted
- How the change relates to other files
- For files with multiple logical changes (e.g., a bug fix AND a refactor in the same file), identify each hunk's purpose

Use `git diff --no-color` output to analyze at the hunk level. Each hunk starts with `@@ ... @@` and represents a contiguous block of change. Determine which hunks belong together logically.

### Step 3: Group Changes into Logical Commits

Group changes by **logical concern**. Each group becomes one commit.

**Grouping Principles (priority order):**

1. **Single Responsibility**: Each commit should represent ONE logical change
2. **Functional Cohesion**: Files/hunks that implement the same feature/fix go together
3. **Dependency Order**: If commit B depends on commit A's changes, A must come first
4. **Type Separation**: Don't mix `feat` and `fix` in the same commit; don't mix `docs` with code changes
5. **Test Co-location**: Tests go with the code they test (same commit)

**Hunk-level splitting**: When a single file has changes belonging to different groups (e.g., a file with both a bug fix and a formatting change), split the file across groups at the hunk level. Each hunk goes to exactly one group.

### Step 4: Determine Commit Order

Order commits so that:

1. Infrastructure/config changes come first (deps, build, CI)
2. Refactors before features (if the feature depends on the refactor)
3. Features before their documentation
4. Independent changes can be in any order
5. The codebase should be in a valid state after each commit

### Step 5: Present the Commit Plan

Display the plan in this format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scan Commit Plan: N commits from M changed files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commit 1/N
  Message: fix(parser): Handle empty input without panic
  Files:
    - src/parser/input.go (3 hunks, 2 lines each)
    - src/parser/input_test.go (entire file)

Commit 2/N
  Message: feat(api): Add batch processing endpoint
  Files:
    - src/api/batch.go (entire file, untracked)
    - src/api/routes.go (1 hunk, 5 lines)
```

For each file, note whether it's staged fully, partially (hunk-level), or as a new untracked file.

**If `--dry-run` was specified, stop here.**

Ask user to confirm the plan. If user wants to adjust grouping, re-plan.

### Step 6: Unstage Any Existing Staged Changes

If there are already-staged changes that need to be re-grouped with other changes:

```bash
git reset HEAD -- .
```

If all already-staged changes form a coherent group on their own, leave them staged and skip them in the following stage step.

### Step 7: Stage and Commit Each Group

For each commit group in order:

**For files that belong entirely to this group:**

```bash
git add <file1> <file2> ...
```

**For files that are split across groups (hunk-level staging):**

Use the hunk stager that ships with `smart-commit`, instead of assembling
patches by hand:

```bash
# The path's index entry must equal HEAD: run `git reset` once before the first commit.
python3 ~/.agents/skills/smart-commit/scripts/stage_hunks.py --list <file>
python3 ~/.agents/skills/smart-commit/scripts/stage_hunks.py --take 0,2,3 <file>
python3 ~/.agents/skills/smart-commit/scripts/stage_hunks.py --take 1 --split 3:1 <file>
```

`--take` stages whole hunks by index, `--split HUNK:GROUP[,GROUP]` keeps only the
named change groups inside one mixed hunk, and `--check` validates the patch
without staging it. The helper refuses a path that already has staged changes,
so hand each file to it once per commit and let later commits start with
`git reset`.

**For untracked files:**

```bash
git add <untracked-file>
```

**Create the commit:**

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body if needed>
EOF
)"
```

**Verify the commit succeeded:**

```bash
git log --oneline -1
```

### Step 8: Final Verification

After all commits are created:

```bash
# Show the commit log
git log --oneline -N  # where N = number of commits created

# Verify no staged changes remain
git diff --cached --name-only

# Verify no unstaged changes remain
git diff --name-only

# Show working tree status
git status
```

Display summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Done! Created N commits:

  abc1234 fix(parser): Handle empty input without panic
  def5678 feat(api): Add batch processing endpoint
  ghi9012 docs(api): Document batch processing endpoint
```

## Commit Message Rules

Every commit message follows
`~/.agents/skills/smart-commit/references/conventional-commits.md`: the
`<type>(scope): <Capitalized description>` format, the type table, the 50/72
subject and body limits, the imperative mood, and the breaking-change footers.
Read it once before planning; every message in the plan must satisfy it.

## Edge Cases

### No Changes At All
Stop and inform the user. Nothing to commit.

### Already-Staged Changes
Warn the user. If the staged changes form a coherent group, commit them as-is. If they should be regrouped with unstaged changes, unstage them first with `git reset HEAD -- .` and re-analyze.

### Single Logical Change
If all changes belong to ONE logical concern, create a single commit. Don't split artificially.

### File-Level Split vs. Hunk-Level Split
- **File-level**: Entire file belongs to one group — simple `git add`
- **Hunk-level**: File has changes for multiple groups — use the hunk stager in Step 7

### Untracked Binary Files
Binary files cannot be diffed. Stage them as whole files.

### Pre-commit Hook Failures
If a commit fails due to pre-commit hooks:
1. Read the hook output
2. Fix the issue (formatting, linting, etc.)
3. Re-stage the fixed files
4. Create a NEW commit (do NOT amend)

### Remaining Unstaged Changes After All Commits
If some changes remain unstaged after all commits, list them for the user and suggest they create a separate WIP commit or leave them for later.

## Hunk Analysis Guide

When analyzing `git diff --no-color` output, each hunk has this structure:

```
@@ -start,count +start,count @@ optional-section-header
 context line
-removed line
+added line
 context line
```

To determine which hunks belong together:

- **Same feature area**: Hunks that modify the same function, class, or module boundary
- **Same concern**: Hunks that address the same bug, feature, or refactoring goal
- **Same commit message**: If you would describe two hunks in the same commit message, they belong together

When in doubt, prefer finer granularity (more commits) over coarser. It's easier to squash commits later than to split them.

## Design Philosophy

- Scans both staged and unstaged changes holistically
- Groups by logical concern at the hunk level, not by file
- Automates the full "stage → commit" pipeline
- Follows Conventional Commits v1.0.0 strictly
- Preserves dependency order between commits
- Requires user confirmation before executing