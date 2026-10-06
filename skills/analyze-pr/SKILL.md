---
name: analyze-pr
description: Analyze a GitHub/GitLab Pull Request by fetching its diff, reading its web description, and generating a comprehensive document. Use when the user provides a PR link and wants to understand what changes the PR introduces, or asks to review/analyze/summarize a pull request.
---

# Analyze Pull Request

Given a PR URL, fetch the code changes and web description, then generate a comprehensive analysis document. The PR is guaranteed to belong to the current local repository.

## Workflow

### Step 1: Parse the PR URL

Extract from the URL:

- **Platform**: GitHub or GitLab
- **Owner/Org**, **Repo**, **PR Number**

Supported formats:

```
https://github.com/{owner}/{repo}/pull/{number}
https://gitlab.com/{owner}/{repo}/-/merge_requests/{number}
```

### Step 2: Fetch PR Metadata

Use the `WebFetch` tool to read the PR page and extract:

- PR title, description, author, labels, linked issues
- Review comments and discussion highlights

For GitHub PRs, also fetch the API endpoint for structured data:

```
https://api.github.com/repos/{owner}/{repo}/pulls/{number}
```

This gives you `base.ref` (base branch name), `head.ref`, `additions`, `deletions`, `changed_files`, etc.

### Step 3: Fetch the PR Branch Locally

```bash
# Record current branch for later restore
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# GitHub
git fetch origin pull/{number}/head:pr-{number}

# GitLab
git fetch origin merge-requests/{number}/head:mr-{number}
```

Do NOT checkout the PR branch — use it as a ref for diff only, to avoid disrupting the working tree.

### Step 4: Generate the Diff

Use `base.ref` from Step 2 as the base branch (do NOT hardcode `main`):

```bash
BASE_BRANCH={base.ref from step 2}

# Changed file list
git diff --name-only origin/$BASE_BRANCH...pr-{number}

# Stats summary
git diff --stat origin/$BASE_BRANCH...pr-{number}

# Full diff
git diff origin/$BASE_BRANCH...pr-{number}

# Commit history
git log --oneline origin/$BASE_BRANCH..pr-{number}
```

### Step 5: Analyze the Changes

For each changed file, understand:

1. **What changed**: additions, deletions, modifications
2. **Why it changed**: infer from commit messages, PR description, and code context
3. **Impact**: which components/modules are affected

Group changes by category:

- **New Features**: new files, new functions, new APIs
- **Bug Fixes**: error handling, logic corrections
- **Refactoring**: code reorganization, naming changes
- **Configuration**: build, CI/CD, dependency changes
- **Documentation**: README, comments, docs
- **Tests**: new or modified tests

### Step 6: Generate the Analysis Document

Create a markdown document:

```markdown
# PR Analysis: {PR Title}

> PR Link: {url}
> Author: {author}
> Date: {date}
> Base Branch: {base} ← {head}

## Summary

{One paragraph overview of what this PR does and why}

## Change Statistics

- Files changed: {count}
- Lines added: {additions}
- Lines deleted: {deletions}

## Detailed Changes

### {Category 1: e.g., New Features}

#### {File or component name}

- **What**: Description of the change
- **Why**: Reason for the change
- **Key code changes**: Brief description of important code modifications

### {Category 2: e.g., Bug Fixes}

...

## Commit History

| Hash | Message | Author |
|------|---------|--------|
| {hash} | {message} | {author} |

## PR Discussion Highlights

{Key points from PR comments and reviews, if any}

## Impact Assessment

- **Breaking changes**: {Yes/No, details}
- **Dependencies affected**: {list}
- **Areas requiring attention**: {list}

## Reviewer Notes

{Any additional observations or recommendations}
```

### Step 7: Save the Diff File

Save the full diff to a local file:

```bash
git diff origin/$BASE_BRANCH...pr-{number} > pr-{number}.diff
```

This `.diff` file contains the complete code changes introduced by the PR.

### Step 8: Save the Analysis Document and Cleanup

Save the analysis document to the current working directory as `pr-analysis-{number}.md`.

Then clean up the temporary branch ref:

```bash
git branch -D pr-{number}
```

Final output files:
- `pr-{number}.diff` — raw diff of all PR changes
- `pr-analysis-{number}.md` — structured analysis document

## Important Notes

- If `gh` CLI is available, prefer it over `WebFetch` for fetching PR data (handles auth automatically).
- If the diff is very large (>5000 lines), summarize by file/module rather than line-by-line.
- Do NOT checkout the PR branch — only use it as a ref for diffing.
- Always clean up the temporary branch ref after analysis.
