---
name: toil-offloading
description: Orchestrate large, decomposable workloads with native Codex team agents. Use when the user asks for toil offloading, broad parallel delegation, multi-project fan-out, or many independent agent tasks; do not use for a small task that is faster to complete directly.
---

# Toil Offloading

Keep the root agent as controller: understand the goal, split work, assign
ownership, integrate results, resolve conflicts, and verify the final outcome.
Use only the native collaboration tools exposed by the current Codex runtime.
Do not launch agent CLIs or `codex exec` as shell subprocesses.

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the agent types advertised by the runtime as the
session contract and send the first useful assignments directly. If an
assignment cannot start or finish, record its actual outcome and continue other
safe, useful work. Reassign only when the task scope and acceptance condition
remain explicit; never replace a native worker with a shell subprocess.

## Route work

- Select agent types from the runtime descriptions according to task complexity,
  cost, and the evidence the assignment must produce.
- Prefer lightweight worker roles for targeted searches, inventories,
  extraction, formatting, repetitive validation, focused test execution, and
  small independent edits with an obvious acceptance condition.
- Prefer stronger reasoning roles for cross-file analysis, ambiguous diagnosis,
  implementation judgment, conflict analysis, or independent review.
- Keep architectural decisions, destructive or externally mutating actions,
  conflict resolution, final integration, and acceptance with the root agent.
- If an assignment exposes materially different complexity, finish or close it
  and create a new bounded assignment with a suitable agent type. Do not
  silently change roles or scope.

## Build the batch

Delegate only tasks that are independently useful. Give every worker:

- one concrete objective and an observable done condition;
- the exact project root or paths in scope;
- whether it is read-only or may edit;
- required evidence and output format;
- relevant constraints from the user and `AGENTS.md`;
- a reminder that other agents may be working in the same checkout, so it must
  preserve unrelated changes and accommodate concurrent edits.

Respect the current runtime's concurrency and nesting limits. Start clearly
independent tasks together, but reserve capacity for follow-up and review.
Prefer a few well-partitioned assignments over duplicate investigations.

## Protect shared work

- Read-only workers may inspect the same project concurrently.
- Never assign overlapping writes in one checkout. Partition ownership by
  project or disjoint path, or create isolated worktrees when that is already
  authorized and appropriate.
- Workers must not commit, submit, deploy, delete, or perform other external or
  destructive actions unless the user explicitly authorized that action.
- Do not treat a worker's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.

## Integrate

Track each assignment through completion. Follow up with the same worker when
its context is valuable; use a separate reviewer when independence adds value.
Before reporting completion, account for every assignment as accepted,
superseded, failed, or cancelled, then give one root-level conclusion.
