# Conventional Commits

The one message format used by `smart-commit`, `scan-commit`, `gen-commit-msg`,
and `create-pr`. Based on
[Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Format

```
<type>[optional scope][optional !]: <Description>

[optional body]

[optional footer(s)]
```

## Types

| Type       | When to Use                                             |
| ---------- | ------------------------------------------------------- |
| `feat`     | A new feature (correlates with MINOR in SemVer)         |
| `fix`      | A bug fix (correlates with PATCH in SemVer)             |
| `docs`     | Documentation only changes                              |
| `style`    | Formatting, missing semi-colons, etc. (not CSS)         |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf`     | Performance improvement                                 |
| `test`     | Adding or correcting tests                              |
| `build`    | Changes to the build system or external dependencies    |
| `ci`       | Changes to CI configuration files and scripts           |
| `chore`    | Other changes that don't modify src or test files       |
| `revert`   | Reverts a previous commit                               |

## Subject line

1. Separate the subject from the body with a **blank line**.
2. Keep the **entire** subject within **~50 characters** (type + scope +
   description). Hard limit: 72.
3. **Capitalize** the description after `<type>(scope):`.
4. **No period** at the end.
5. Use the **imperative mood**.
6. Write commit messages in **English**.

## Body

7. **Wrap at 72 characters.**
8. Explain **what and why**, not how.

## Scope, breaking changes, footers

- `scope`: a noun naming the section of the codebase, inferred from the changed
  paths. Omit it when the change spans unrelated areas.
- `!` after the type or scope marks a BREAKING CHANGE.
- `BREAKING CHANGE: <details>` is the footer for the same change.
- `Closes #123` / `Refs #456` reference issues.

## Optional body sections

A large change may list the areas it touched:

```
Key changes:
- Add pagination parameters to the endpoint
- Update the queries to support the cursor
```

## Example

```
feat(api): Add pagination support to the user endpoint

Enable cursor-based pagination for the user list API so large
datasets do not time out.

Key changes:
- Add pagination parameters to the endpoint
- Update the queries to support the cursor

Refs: #123
```
