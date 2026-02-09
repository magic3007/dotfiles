---
name: gen-commit-msg
description: Generate intelligent commit messages based on staged changes. Invoke with /gen-commit-msg.
---

# Generate Commit Message

Generate a well-formatted commit message based on staged changes.

## Usage

```
/gen-commit-msg [--amend] [--scope <scope>]
```

**Arguments:**

- `--amend`: Amend the previous commit instead of creating new
- `--scope <scope>`: Force a specific scope (e.g., `workflow`, `engine`)

## Workflow

### Step 1: Analyze Changes

```bash
# Check staged files
git diff --cached --name-only

# Check staged content
git diff --cached

# Check recent commit style
git log --oneline -5
```

### Step 2: Categorize Changes

| Type       | When to Use                     |
| ---------- | ------------------------------- |
| `feat`     | New feature or capability       |
| `fix`      | Bug fix                         |
| `docs`     | Documentation only              |
| `refactor` | Code change without feature/fix |
| `test`     | Adding or fixing tests          |
| `chore`    | Build, deps, config changes     |
| `perf`     | Performance improvement         |

### Step 3: Determine Scope

Infer scope from changed files:

- `src/` or `lib/` → infer from subdirectory (e.g., `src/auth/` → `auth`)
- `app/` or `client/` → `app` or `client`
- `server/` or `api/` → `api`
- `test/` or `tests/` → `test`
- `docs/` → `docs`
- `config/` or `conf/` → `config`
- `scripts/` → `scripts`
- Multiple areas → omit scope or use broader term

### Step 4: Generate Message

**Format:**

```
<type>(<scope>): <subject>

<body>

[Optional sections:]
Key changes:
- change 1
- change 2

Refs: #123, #456
```

**Rules:**

- Subject: imperative mood, ~50-72 chars, no period
- Body: explain "why" not "what", wrap at 72 chars
- Key changes: bullet list of main modifications (for complex commits)
- Refs: reference issues/PRs if applicable

### Step 5: Confirm and Commit

Show preview:

```
─────────────────────────────────────
feat(workflow): add vision support to ImageProcessing

Add ImageProcessingWorkflow for vision-language processing.
Supports image inputs alongside text prompts.
─────────────────────────────────────
```

Ask user to confirm, then execute:

```bash
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```

## Examples

**Single file fix:**

```
fix(auth): handle null user in login validation

Return proper error instead of raising exception when
user object is null during authentication.
```

**Multi-file feature:**

```
feat(api): add pagination support to user endpoint

Enable cursor-based pagination for user list API to
improve performance with large datasets.

Key changes:
- Add pagination parameters to API endpoint
- Update database queries to support cursor
- Add pagination metadata to response
```

**Docs only:**

```
docs: update API documentation examples

Add new endpoint examples and update authentication
flow documentation with clearer examples.
```

______________________________________________________________________

<!--
================================================================================
                            MAINTAINER GUIDE
================================================================================

Location: .claude/commands/gen-commit-msg.md
Invocation: /gen-commit-msg

## Design Philosophy

- Automates commit message generation following Conventional Commits format
- Matches repository's existing style
- Requires user confirmation before commit

## How to Update

### Adding New Scopes
Update "Determine Scope" section with new file path mappings.

### Changing Format
Update "Generate Message" format template and rules.

================================================================================
-->
