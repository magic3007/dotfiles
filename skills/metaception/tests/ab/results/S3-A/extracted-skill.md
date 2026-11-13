---
name: github-actions-stale-node-modules-cache
description: |
  Diagnose and fix GitHub Actions CI failures caused by a stale `node_modules` cache
  restored via `actions/cache` `restore-keys` prefix matching. Use when: (1) CI fails on a
  PR but `npm test` passes locally every time, (2) the same commit fails deterministically
  on CI re-runs (not a flake) while the previous commit was green, (3) the PR diff touches
  only test files or string literals yet tests now fail with assertion mismatches like
  "AssertionError: expected 1999 to be 2000", (4) `npm ls <pkg>` in CI prints an older
  version than local even though `package.json` and `package-lock.json` agree on the newer
  one, (5) the workflow caches `path: node_modules` with `restore-keys` and has no `npm ci`
  step. Covers `actions/cache`, `actions/setup-node` `cache: 'npm'`, `hashFiles`, and `npm ci`.
  Also flags the look-alike `npm ERR! code EINTEGRITY` failure, which has a different root cause.
author: Claude Code
version: 1.0.0
date: 2026-11-10
---

# GitHub Actions Stale node_modules Cache

## Problem

A workflow caches the entire `node_modules` directory with `actions/cache` and supplies
`restore-keys` as a prefix fallback, but never runs `npm ci`. Because `restore-keys` matches
by **prefix**, the cache action restores an old `node_modules` tree built from an earlier
`package-lock.json` even after the lockfile hash changed. CI then runs tests against
dependency versions that no longer match the lockfile, so a PR that only reworded a test
assertion fails with a numeric mismatch. Nothing in the test code or the lockfile is wrong,
which is why the failure is invisible locally.

## Context / Trigger Conditions

- CI fails on the PR while local `npm test` passes repeatedly (20/20 green in this case).
- Re-running the same commit on CI fails the same way — deterministic, not a flake.
- The previous commit was green on CI, and the current diff only changes test text/assertion
  wording, not numbers or logic.
- Test output shows a value mismatch rather than a compile or import error, e.g.:
  ```
  FAIL  test/billing.spec.ts
  AssertionError: expected 1999 to be 2000
   ❯ test/billing.spec.ts:42:20
  ```
- `npm ls <pkg>` prints a different version on CI than locally, while `package.json` and
  `package-lock.json` both pin the newer version:
  ```
  $ npm ls @acme/pricing
  acme-api@2.4.0
  └── @acme/pricing@1.9.0        # local
  # CI: @acme/pricing@1.8.3
  ```
- The workflow has all of these traits together:
  ```yaml
  - uses: actions/setup-node@v4
    with: { node-version: '20', cache: 'npm' }
  - uses: actions/cache@v4
    with:
      path: node_modules
      key: ${{ runner.os }}-nm-${{ hashFiles('package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-nm-
  - run: npm test
  ```
- Environment: Node 20.11.1 / npm 10.8.2, `runs-on: ubuntu-24.04`, `actions/checkout@v4`,
  `actions/cache@v4`, `actions/setup-node@v4`.

## Solution

### Step 1: Rule out the test itself

Confirm the diff cannot explain the failure before suspecting the environment:

```sh
git diff   # only a string literal changed; numeric expectations untouched
```

Then rule out the usual environmental suspects with a local A/B. In this case
`TZ=UTC npm test` stayed green, eliminating timezone/float explanations.

### Step 2: Compare the installed dependency version between local and CI

Pick the package that plausibly drives the failing assertion and print its resolved
version in both places:

```sh
npm ls @acme/pricing            # local
```

Add the same command as a temporary CI step. A mismatch (local `1.9.0`, CI `1.8.3`)
proves CI is not running the locked dependency tree.

### Step 3: Confirm the lockfile is not the problem

```sh
grep -n '"@acme/pricing"' package.json package-lock.json
# package.json:12:    "@acme/pricing": "^1.9.0",
# package-lock.json:141:  "node_modules/@acme/pricing": { "version": "1.9.0", ...
```

If `package.json` and `package-lock.json` agree, the wrong version can only come from a
restored artifact — the cache.

### Step 4: Read the cause off the cache configuration

Three facts combine into the failure:

1. `restore-keys` entries are matched as **prefixes**. `${{ runner.os }}-nm-` matches any
   previously saved `node_modules` cache, including one built before the lockfile changed.
2. `hashFiles('package-lock.json')` only affects the exact `key`. A prefix hit bypasses it
   entirely, so a lockfile change does not invalidate the cache.
3. `actions/setup-node` with `cache: 'npm'` caches only npm's download cache (`~/.npm`). It
   never installs dependencies. With no `npm ci` step in the workflow, the restored
   `node_modules` is used verbatim.

### Step 5: Prove it in CI before changing anything

Add two temporary steps:

```yaml
- run: npm ls @acme/pricing        # → @acme/pricing@1.8.3
- run: rm -rf node_modules && npm ci && npm ls @acme/pricing   # → @acme/pricing@1.9.0
```

`npm test` passes after the reinstall, which closes the loop.

### Step 6: Apply the fix — cache the download cache, install explicitly

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}
- run: npm ci
- run: npm test
```

Two changes, both required by this incident: cache `~/.npm` instead of `node_modules`, and
run `npm ci` so the tree always matches the lockfile. The `restore-keys` prefix fallback is
removed so no stale artifact can be restored at all.

## Verification

1. After the fix, push several consecutive commits — including commits that touch only test
   files — and confirm every CI run is green (6 consecutive green commits in this case).
2. Run the local equivalent of a clean install to confirm the lockfile tree is what passes:
   ```sh
   rm -rf node_modules && npm ci && npm test
   ```
3. Expected outcome: `npm ls @acme/pricing` reports `1.9.0` on CI, matching
   `package-lock.json`, and `vitest run` exits green.

## Example

**Scenario**: A PR on `acme-api@2.4.0` only rewords an assertion message in
`test/billing.spec.ts`, yet CI fails deterministically while local `npm test` is green 20
times in a row.

**Before**:

```yaml
- uses: actions/setup-node@v4
  with: { node-version: '20', cache: 'npm' }
- uses: actions/cache@v4
  with:
    path: node_modules
    key: ${{ runner.os }}-nm-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-nm-
- run: npm test
```

```
FAIL  test/billing.spec.ts
AssertionError: expected 1999 to be 2000
 ❯ test/billing.spec.ts:42:20
```

**After**:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}
- run: npm ci
- run: npm test
```

```
@acme/pricing@1.9.0     # npm ls in CI now matches package-lock.json
# npm test passes
```

## Notes

- Same symptom, different root cause: `npm ERR! code EINTEGRITY` /
  `sha512-... integrity checksum failed when using sha512` also appears as "CI red, local
  green", but there the lockfile's tarball integrity does not match the registry because the
  upstream republished that version. Deleting `restore-keys` and adding `npm ci` do **not**
  help. Fix with `npm cache clean --force` plus pinning to a version that was not
  republished (or `npm ci --prefer-online`). Check for this error before applying the cache
  fix.
- Untested variants — do not assume they behave the same: whether `cache: 'pnpm'` has the
  same failure mode (pnpm's store and `node_modules` layout differ, but the cache mechanism
  is similar); whether GitHub-hosted runner cache eviction (7 days / 10 GB) would make the
  problem self-heal; whether keeping `restore-keys` and only adding `npm ci` is sufficient
  (no controlled comparison was run — the prefix fallback was removed outright).
- `actions/setup-node`'s `cache: 'npm'` is not a substitute for `npm ci`; it only manages
  `~/.npm`.
- Do not use this skill when CI fails identically locally, when the failure is a genuine
  flake, or when `npm ls` already matches the lockfile on CI.

## References

- [GitHub Docs: Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) — `restore-keys` are checked sequentially for partial (prefix) matches when no exact key match exists.
- [actions/setup-node README](https://github.com/actions/setup-node#caching-global-packages-data) — `cache: 'npm'` caches npm's global package data, not `node_modules`.
- [npm docs: npm ci](https://docs.npmjs.com/cli/commands/npm-ci) — clean install strictly from `package-lock.json`.
