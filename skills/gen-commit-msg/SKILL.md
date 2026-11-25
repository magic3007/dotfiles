---
name: gen-commit-msg
description: Generate intelligent commit messages based on staged changes following Conventional Commits format.
---

# Generate Commit Message

Generate a well-formatted commit message based on staged changes.

## Usage

Invoke with `/gen-commit-msg` or when the task matches.

**Arguments:**

- `--amend`: Amend the previous commit instead of creating new
- `--scope <scope>`: Force a specific scope (e.g., `auth`, `api`)

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

### Step 2: Pick the Type and Scope

The types, subject and body limits, imperative mood, and breaking-change
footers are in `~/.agents/skills/smart-commit/references/conventional-commits.md`.
Read it before writing.

Infer the scope from the changed paths:

- `src/` or `lib/` → the subdirectory (e.g., `src/auth/` → `auth`)
- `app/`, `client/`, `server/`, `api/` → `app`, `client`, `api`
- `test/` or `tests/` → `test`
- `docs/` → `docs`
- `config/` or `conf/` → `config`
- `scripts/` → `scripts`
- Multiple areas → omit scope or use a broader term

### Step 3: Generate Message

Follow the reference's format. For a complex commit, add the optional
`Key changes:` and `Refs:` sections it describes.

### Step 4: Confirm and Commit

Show preview, ask user to confirm, then execute:

```bash
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```

## Examples

**Single file fix:**

```
fix(auth): Handle null user in login validation

Return proper error instead of raising exception when
user object is null during authentication.
```

**Multi-file feature:**

```
feat(api): Add pagination support to the user endpoint

Enable cursor-based pagination for user list API to
improve performance with large datasets.

Key changes:
- Add pagination parameters to API endpoint
- Update database queries to support cursor
- Add pagination metadata to response
```

**Docs only:**

```
docs: Update API documentation examples

Add new endpoint examples and update authentication
flow documentation with clearer examples.
```