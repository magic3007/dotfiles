---
name: smart-commit
description: Analyze staged changes and split them into multiple logical commits following Conventional Commits. Invoke with /smart-commit.
---

# Smart Commit

Analyze all currently staged git changes, group them by logical concern, and create multiple well-structured commits following [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Usage

```
/smart-commit [--dry-run]
```

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

1. Separate subject from body with a **blank line** — the subject is used in `git log --oneline`, `git shortlog`, etc.
2. Limit the **entire** subject line to **~50 characters** (type + scope + description combined). Hard limit: 72 chars.
3. **Capitalize** the description after `<type>(scope):` — e.g., `feat(auth): Add JWT refresh`, NOT `feat(auth): add JWT refresh`
4. **No period** at the end of the subject line
5. Use **imperative mood** — "Fix bug", "Add feature", NOT "Fixed bug" or "Adds feature". The subject should complete: "If applied, this commit will _____."
6. All commit messages in **English**

**Body:**

7. **Wrap at 72 characters** — ensures readability in 80-column terminals
8. Explain **what and why**, not how — the diff shows the how; the body provides context, motivation, and reasoning

**Scope & Breaking Changes:**

- `scope`: noun describing the section of the codebase (e.g., `auth`, `api`, `parser`)
- `!` after type/scope: indicates a BREAKING CHANGE (correlates with MAJOR in SemVer)
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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

   If a file has both related and unrelated changes (i.e., partial staging needed), use:

   ```bash
   git add -p <file>
   ```

   and guide the user through hunk selection, OR stage the whole file if all changes belong to this commit.

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Edge Cases

### Single Logical Change
If all staged changes belong to ONE logical concern, create a single commit. Don't split artificially.

### Partial File Staging Needed
When a file contains changes for multiple commits, use `git add -p` for patch-level staging. Explain to the user which hunks belong to which commit.

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

---

<!--
================================================================================
                            MAINTAINER GUIDE
================================================================================

Location: .claude/commands/smart-commit.md
Invocation: /smart-commit

## Design Philosophy

- Analyzes staged changes holistically before committing
- Groups by logical concern, not by file
- Follows Conventional Commits v1.0.0 strictly
- Preserves dependency order between commits
- Requires user confirmation before executing
- Tests co-located with implementation, not separated

## How to Update

### Adding New Types
Update the "Types" table with new Conventional Commits types.

### Changing Grouping Logic
Update "Grouping Principles" and "Common Grouping Patterns" sections.

### Changing Output Format
Update "Present the Commit Plan" and "Final Verification" sections.

================================================================================
-->
