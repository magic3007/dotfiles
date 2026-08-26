# Building Mode Prompt

## Context

You are one link in an iterative chain. A shell script (loop.sh) calls you in a loop — each call is a fresh context. Do a reasonable chunk of work this iteration, then exit cleanly. Don't try to finish everything; don't artificially limit yourself to one tiny task either. The next iteration will pick up where you left off.

## Instructions

0a. Study `specs/*` to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. For reference, the application source code is in `src/*`.

1. Follow @IMPLEMENTATION_PLAN.md and choose the highest-priority incomplete items that form a coherent chunk. Before making changes, search the codebase — don't assume not implemented. Ultrathink.

2. Implement completely. No placeholders, no stubs.

3. Run validation (from AGENTS.md):
   - Tests must pass (run with `--coverage` flag, e.g. `pnpm test -- --coverage`)
   - Typecheck must pass
   - Lint must pass

4. Code review checklist (self-review before committing):
   - [ ] Implementation matches spec acceptance criteria
   - [ ] No regressions in existing tests
   - [ ] Consistent with codebase patterns
   - [ ] Edge cases from spec are handled
   - [ ] No debug artifacts left behind

5. If any gate fails: fix the issue, re-run validation. Do not commit broken code.

6. When gates pass: update @IMPLEMENTATION_PLAN.md, then `git add -A && git commit` with a descriptive message.

7. When ALL tasks are complete, output the full coverage report and verify targets:
   - Line coverage ≥ 80%
   - Branch coverage ≥ 70%
   - New code coverage ≥ 90%
   If coverage is below target, add tests until targets are met.

8. After coverage targets are met, add `STATUS: COMPLETE` as the first line of @IMPLEMENTATION_PLAN.md. (loop.sh will run a Codex cross-review automatically — you don't need to do this yourself.)

## Guardrails

99999. Important: Capture the why in documentation — tests and implementation importance.

999999. Important: Single sources of truth, no migrations/adapters. If unrelated tests fail, fix them.

9999999. Create git tags after successful builds (start at 0.0.1).

99999999. Keep @IMPLEMENTATION_PLAN.md current with learnings — future iterations depend on this.

999999999. Implement completely. Placeholders waste iterations redoing the same work.

9999999999. Update @AGENTS.md with operational learnings (keep it ≤60 lines).

99999999999. For bugs found, resolve them or document them in @IMPLEMENTATION_PLAN.md.

999999999999. Periodically clean completed items from @IMPLEMENTATION_PLAN.md.

---

## Customization

- Replace `src/*` with your source directory
- Update AGENTS.md with your stack's build/test/lint commands
