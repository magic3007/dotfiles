---
name: vitest-config-shadows-vite-config-alias
description: |
  Fix "Failed to load url @acme/core (resolved id: @acme/core). Does the file exist?" in a
  pnpm monorepo where vitest runs fine under `pnpm dev` and `pnpm -w build` but fails in tests.
  Use when: (1) vitest reports Failed to load url / Cannot find module for a workspace-internal
  package, (2) the same import works in the Vite dev server and in the production build,
  (3) the internal package's package.json `main` points at TypeScript source (e.g.
  `./src/index.ts`) instead of `dist`, (4) `vite-tsconfig-paths` (or any alias/plugin) is
  registered only in `vite.config.ts` while a separate `vitest.config.ts` exists. Covers
  Vitest 2.x, Vite, pnpm workspaces, tsconfig `paths`.
author: Claude Code
version: 1.0.0
date: 2026-11-10
---

# Vitest Config Shadows Vite Config: Missing Path Alias in Tests

## Problem

In a pnpm monorepo, `apps/web` tests fail to resolve an internal workspace package
(`@acme/core`) even though the dependency is correctly linked and the exact same import
works in the dev server and in a full workspace build.

The error names the bare specifier (`resolved id: @acme/core`), which points at Vite's module
resolution rather than at pnpm, so the usual "the workspace link is missing" and "the package
isn't built" hypotheses both send you down the wrong path. The real cause is a config-file
precedence rule: when a `vitest.config.ts` exists, Vitest uses it and does **not** merge
`vite.config.ts`, so every plugin and alias declared only in `vite.config.ts` is absent during
tests. Because the internal package's `main` points at TypeScript source, there is nothing
else that could resolve the specifier once the alias plugin is gone.

## Context / Trigger Conditions

- Exact error from Vitest:
  ```
  FAIL  src/lib/cart.test.ts [ src/lib/cart.test.ts ]
  Error: Failed to load url @acme/core (resolved id: @acme/core). Does the file exist?
   ❯ src/lib/cart.ts:1:23
        1 | import { priceCart } from '@acme/core'
  ```
- The failing specifier is a workspace-internal package (`@acme/*`) imported by bare name.
- `pnpm --filter <app> dev` works and the page renders in the browser.
- `pnpm -w build` succeeds.
- The internal package's `package.json` has `"main": "./src/index.ts"` (source, not `dist`).
- The app has a `vitest.config.ts` **and** a separate `vite.config.ts`.
- `vite.config.ts` registers `tsconfigPaths()` (or custom `resolve.alias`) but
  `vitest.config.ts` has only `test` options, no `plugins`.
- Environment in the observed case: Node v20.11.1, pnpm 9.12.3, Vitest 2.1.8.

## Solution

### Step 1: Rule out workspace linking and build output first

Both are cheap to check and both were wrong hypotheses in the observed case.

```sh
ls -la apps/web/node_modules/@acme/
# core -> ../../../../packages/core   (symlink present)

pnpm -F @acme/web why @acme/core
# dependencies:
# @acme/core 0.3.1
```

If the symlink and the dependency entry are present, linking is not the problem. Rebuilding
the workspace (`pnpm -w build`) and re-running the test is also worth one attempt; if the
error text is byte-for-byte identical, the missing artifact is not the cause either.

### Step 2: Inspect the internal package's entry point and the test config

```sh
cat packages/core/package.json
# { "name": "@acme/core", "version": "0.3.1",
#   "main": "./src/index.ts", "types": "./src/index.ts" }
```

`main` pointing at `src/index.ts` means Node/Vite resolution cannot load this package without
help from a TS-aware alias — the `tsconfig.json` `paths` mapping is what makes it work:

```sh
cat apps/web/tsconfig.json | grep -A3 paths
# "paths": { "@acme/core": ["../../packages/core/src/index.ts"] }
```

Then compare which plugins each config file registers:

```sh
cat apps/web/vitest.config.ts
# export default defineConfig({ test: { environment: 'jsdom' } })   <- no plugins

grep -n "tsconfigPaths\|alias" apps/web/vite.config.ts
# 3:import tsconfigPaths from 'vite-tsconfig-paths'
# 7:  plugins: [react(), tsconfigPaths()],
```

The asymmetry is the diagnosis: Vitest loads `vitest.config.ts` in preference to
`vite.config.ts`, so `tsconfigPaths()` never runs during tests, the `paths` mapping is never
applied, and the bare specifier `@acme/core` has no resolver.

### Step 3: Register the same resolver plugin in `vitest.config.ts`

```ts
// apps/web/vitest.config.ts
import tsconfigPaths from 'vite-tsconfig-paths'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: { environment: 'jsdom' },
})
```

Equivalently, declare the alias explicitly with `resolve.alias` in `vitest.config.ts`, or
delete `vitest.config.ts` and put the `test` block inside `vite.config.ts` so a single config
serves both. Whichever you pick, the invariant is: **every plugin or alias the tests depend
on must live in the config file Vitest actually loads.**

## Verification

1. Run the test suite for the affected package:
   ```sh
   pnpm -F @acme/web test
   #  ✓ src/lib/cart.test.ts (7 tests) 312ms
   #  Test Files  1 passed (1)
   ```
2. Clear the Vite cache and re-run, to prove the pass is not a cache artifact:
   ```sh
   rm -rf apps/web/node_modules/.vite && pnpm -F @acme/web test
   #  ✓ src/lib/cart.test.ts (7 tests) 298ms
   ```
3. Expected outcome: the suite passes both times, with the previously failing
   `Failed to load url @acme/core` error gone.

## Example

**Scenario**: `apps/web` in a pnpm workspace imports `priceCart` from `@acme/core`. Dev
server and `pnpm -w build` are green; `vitest` fails on the first import line.

**Before**:

```ts
// apps/web/vitest.config.ts
import { defineConfig } from 'vitest/config'
export default defineConfig({ test: { environment: 'jsdom' } })
```

```
FAIL  src/lib/cart.test.ts [ src/lib/cart.test.ts ]
Error: Failed to load url @acme/core (resolved id: @acme/core). Does the file exist?
 ❯ src/lib/cart.ts:1:23
```

**After**:

```ts
// apps/web/vitest.config.ts
import tsconfigPaths from 'vite-tsconfig-paths'
import { defineConfig } from 'vitest/config'
export default defineConfig({
  plugins: [tsconfigPaths()],
  test: { environment: 'jsdom' },
})
```

```
 ✓ src/lib/cart.test.ts (7 tests) 312ms
 Test Files  1 passed (1)
```

## Notes

- **Same-looking error, different root cause.** In another repository,
  `import { x } from '@acme/core'` produced `Cannot find module '@acme/core'`, but there
  `packages/core/package.json` had `"main": "./dist/index.js"` plus an `exports` map and
  `dist/` was never built (gitignored, no build step in CI). That is a **build-order**
  problem; adding `tsconfigPaths()` to `vitest.config.ts` had no effect at all. Always read
  the internal package's `main`/`exports` before choosing a fix: `main` → `src/*.ts` means
  alias/resolver problem, `main` → `dist/*` with a missing `dist/` means build problem.
- Not verified: a colleague hit the same error in CI (`pnpm -F @acme/web test --run`) but the
  CI failure was never reproduced locally, so the CI root cause is unconfirmed.
- Not verified: behaviour under Vitest 2.x multi-package mode (`vitest --workspace`) was not
  tested.
- This is a general Vite/Vitest config-precedence rule, not pnpm-specific; the pnpm workspace
  just makes the bare `@acme/*` specifier common.
- When NOT to use this skill: when the failing specifier is an external npm package (then
  check installation/`exports`), or when the internal package ships compiled `dist` output
  that simply has not been built yet.
