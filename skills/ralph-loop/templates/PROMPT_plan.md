# Planning Mode Prompt

## Instructions

0a. Study `specs/*` to learn all application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `src/lib/*` to understand shared utilities & components.
0d. For reference, the application source code is in `src/*`.

1. Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect) and study existing source code in `src/*`, comparing it against `specs/*`. Analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority of items yet to be implemented. Ultrathink. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Treat `src/lib` as the project's standard library for shared utilities and components. Prefer consolidated, idiomatic implementations there over ad-hoc copies.

2. When you are confident the plan is complete and covers all specs:
   - Add `STATUS: PLANNING_COMPLETE` as the **first line** of @IMPLEMENTATION_PLAN.md
   - This sentinel signals loop.sh that planning is done

ULTIMATE GOAL: We want to achieve [PROJECT_GOAL]. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md. Document the plan to implement it in @IMPLEMENTATION_PLAN.md.

---

## Customization Notes

Replace `[PROJECT_GOAL]` with your actual goal, e.g.:
- "a fully functional mood board creation app"
- "a CLI tool for managing docker containers"
- "complete test coverage for all auth flows"

Adjust paths if your source code isn't in `src/`:
- `src/*` → your source directory
- `src/lib/*` → your shared utilities directory
