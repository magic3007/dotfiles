---
name: smart-commit
description: Analyze staged changes and split them into multiple logical commits following Conventional Commits.
---

# Smart Commit

Analyze all currently staged git changes, group them by logical concern, and create multiple well-structured commits following [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Usage

Invoke with `/smart-commit` or when the task matches.

**Arguments:**

- `--dry-run`: Only show the proposed commit plan without executing

## Conventional Commits Specification

Every commit message MUST follow this format:

```
<type>[optional scope][optional !]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type       | When to Use                                          |
| ---------- | ---------------------------------------------------- |
| `feat`     | A new feature (correlates with MINOR in SemVer)      |
| `fix`      | A bug fix (correlates with PATCH in SemVer)          |
| `docs`     | Documentation only changes                           |
| `style`    | Formatting, missing semi-colons, etc. (not CSS)      |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf`     | Performance improvement                              |
| `test`     | Adding or correcting tests                           |
| `build`    | Changes to build system or external dependencies     |
| `ci`       | Changes to CI configuration files and scripts        |
| `chore`    | Other changes that don't modify src or test files    |
| `revert`   | Reverts a previous commit                            |

### The 50/72 Rule & Formatting Rules

**Subject line (first line):**

1. Separate subject from body with a **blank line**
2. Limit the **entire** subject line to **~50 characters** (type + scope + description combined). Hard limit: 72 chars.
3. **Capitalize** the description after `<type>(scope):`
4. **No period** at the end of the subject line
5. Use **imperative mood**
6. All commit messages in **English**

**Body:**

7. **Wrap at 72 characters**
8. Explain **what and why**, not how

**Scope & Breaking Changes:**

- `scope`: noun describing the section of the codebase
- `!` after type/scope: indicates a BREAKING CHANGE
- `BREAKING CHANGE:` footer for breaking change details
- `Closes #123` / `Refs #456` in footer to reference issues

## Workflow

### Step 1: Gather Staged Changes

```bash
# List all staged files
git diff --cached --name-only

# Get full staged diff
git diff --cached

# Get staged file stats (additions/deletions per file)
git diff --cached --stat
```

**If no staged changes exist, stop and inform the user.**

### Step 2: Read and Understand All Changed Files

For each staged file, read the full diff carefully. Understand:
- What was changed (added, modified, deleted)
- Why it was changed (bug fix, new feature, refactor, etc.)
- How files relate to each other (shared feature, shared module, dependency chain)

### Step 3: Group Changes into Logical Commits

Analyze all staged changes and group them by **logical concern**. Each group becomes one commit.

**Grouping Principles (priority order):**

1. **Single Responsibility**: Each commit should represent ONE logical change
2. **Functional Cohesion**: Files that implement the same feature/fix go together
3. **Dependency Order**: If commit B depends on commit A's changes, A must come first
4. **Type Separation**: Don't mix `feat` and `fix` in the same commit; don't mix `docs` with code changes
5. **Test Co-location**: Tests go with the code they test (same commit), NOT in a separate commit

**Common Grouping Patterns:**

| Pattern | Example |
| --- | --- |
| Feature + its tests | `feat(auth): Add JWT token refresh` (includes both `src/auth/refresh.ts` and `test/auth/refresh.test.ts`) |
| Config/dependency change | `build(deps): Upgrade axios to v1.6` |
| Documentation update | `docs(api): Update authentication examples` |
| Independent bug fixes | Each fix = separate commit |
| Refactor + affected tests | `refactor(parser): Simplify AST traversal` |
| Style/formatting batch | `style: Apply prettier formatting` (can batch unrelated files) |

**Anti-Patterns (DO NOT do these):**

- One commit per file when files are logically related
- Mixing unrelated changes in one commit
- Putting all tests in a separate commit from their implementation
- Mixing formatting changes with logic changes

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
Commit Plan: N commits from M staged files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commit 1/N
  Message: fix(parser): Handle empty input without panic
  Files:
    - src/parser/input.go
    - src/parser/input_test.go

Commit 2/N
  Message: feat(api): Add batch processing endpoint
  Files:
    - src/api/batch.go
    - src/api/batch_test.go
    - src/api/routes.go

Commit 3/N
  Message: docs(api): Document batch processing endpoint
  Files:
    - docs/api/batch.md
```

**If `--dry-run` was specified, stop here.**

Ask user to confirm the plan. If user wants to adjust grouping, re-plan.

### Step 6: Execute Commits Sequentially

For each commit in order:

1. **Unstage everything first** (only before the first commit):

   ```bash
   git reset HEAD -- .
   ```

2. **Stage only the files for this commit:**

   ```bash
   git add <file1> <file2> ...
   ```

   If a file has both related and unrelated changes (i.e., partial staging needed),
   use `git add -p <file>` when it is interactive, otherwise stage hunk by hunk with
   the bundled helper (see [Hunk-level staging](#hunk-level-staging)). Stage the whole
   file when every change in it belongs to this commit.

3. **Create the commit:**

   ```bash
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <description>

   <body if needed>
   EOF
   )"
   ```

4. **Verify the commit succeeded:**

   ```bash
   git log --oneline -1
   ```

### Step 7: Final Verification

After all commits are created:

```bash
# Show the commit log
git log --oneline -N  # where N = number of commits created

# Verify no staged changes remain
git diff --cached --name-only

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

## Edge Cases

### Single Logical Change
If all staged changes belong to ONE logical concern, create a single commit. Don't split artificially.

### Partial File Staging Needed
When a file contains changes for multiple commits, use `git add -p` for patch-level staging. Explain to the user which hunks belong to which commit.

### Hunk-level staging
`git add -p` needs an interactive TTY and cannot select *within* a hunk. When it is
unavailable, or when one hunk mixes two concerns, drive the index directly with
`scripts/stage_hunks.py` (bundled with this skill):

```bash
# 1. The diff must still be staged (or already reset) — inspect hunks and change groups
python3 <skill>/scripts/stage_hunks.py --list <path>

# 2. Index must equal HEAD for that path, so reset once before the first commit
git reset

# 3. Stage whole hunks, and within a mixed hunk only its 2nd change group
python3 <skill>/scripts/stage_hunks.py --take 0,1,2,4,5 <path>
python3 <skill>/scripts/stage_hunks.py --take 1,2,3 --split 5:1 <path>
```

The helper reads the file's full diff (working tree vs HEAD), rewrites the chosen
subset into a patch — downgrading unselected `-`/`+` pairs inside a split hunk into
context lines and recomputing every `@@ -a,n +b,m @@` — and applies it with
`git apply --cached`. It refuses to run when the path already has staged changes.

Verify each intermediate commit actually builds/runs before creating it; a
broken intermediate tree is worse than one large commit:

```bash
git stash push --keep-index -m verify   # working tree drops to the staged state
<run the affected tests>
git stash pop                           # bring back the rest of the changes
git commit ...                          # then commit the staged subset
git add -A                              # the remainder becomes the next commit
```

One file may only be handed to the helper once per commit — the index must start
at HEAD, and later commits pick up the remainder with `git add -A`.

### Pre-commit Hook Failures
If a commit fails due to pre-commit hooks:
1. Read the hook output
2. Fix the issue (formatting, linting, etc.)
3. Re-stage the fixed files
4. Create a NEW commit (do NOT amend)

### Unstaged Changes Exist
If there are also unstaged changes in the working tree:
1. Only operate on what is currently staged
2. Warn the user that unstaged changes exist and will not be committed
3. After completing all commits, remind user of remaining unstaged changes

## Examples

### Example: Mixed Feature + Fix + Docs

**Staged files:**
- `src/auth/login.ts` (bug fix: null check)
- `src/auth/login.test.ts` (test for the fix)
- `src/api/users.ts` (new endpoint)
- `src/api/users.test.ts` (tests for new endpoint)
- `docs/api/users.md` (documentation)
- `package.json` (new dependency)

**Commit Plan:**

```
Commit 1/4: build(deps): Add zod validation library
  → package.json

Commit 2/4: fix(auth): Add null check for user in login flow
  → src/auth/login.ts, src/auth/login.test.ts

Commit 3/4: feat(api): Add user listing endpoint
  → src/api/users.ts, src/api/users.test.ts

Commit 4/4: docs(api): Add user endpoint documentation
  → docs/api/users.md
```

### Example: Pure Refactor

**Staged files:**
- `src/utils/string.ts` (extracted helper)
- `src/parser/tokenizer.ts` (uses new helper)
- `src/parser/tokenizer.test.ts` (updated tests)

**Commit Plan:**

```
Commit 1/1: refactor(parser): Extract string utilities from tokenizer
  → src/utils/string.ts, src/parser/tokenizer.ts, src/parser/tokenizer.test.ts
```

(Single commit because all changes are part of one refactor.)