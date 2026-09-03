---
name: toil-offloading
description: "Orchestrate decomposable workloads with native Codex team agents: the root agent analyzes, decides, partitions, integrates, and accepts while subagents execute bounded investigation, implementation, testing, and repetitive work. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading

Keep the root agent as orchestrator, not the default implementer. The root owns
goal clarification, decomposition, cross-cutting analysis, architectural and
priority decisions, assignment boundaries, conflict resolution, integration,
and final acceptance. Delegate the bounded execution work: repository searches,
diagnosis, implementation, refactoring, data extraction, artifact generation,
and focused verification.

Subagents are not read-only by default. Give them the write scope and local
validation needed to finish their assignments. Use read-only assignments only
when the work is genuinely inspection-only, the user requested it, or write
isolation cannot be made safe.

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
  non-trivial implementation, conflict analysis, or independent review.
- Keep architectural decisions, destructive or externally mutating actions,
  conflict resolution, final integration, and acceptance with the root agent.
- Let workers make ordinary implementation decisions inside their assignment
  contract. Ask them to return cross-cutting choices or scope changes to the
  root instead of silently expanding the assignment.
- If an assignment exposes materially different complexity, finish or close it
  and create a new bounded assignment with a suitable agent type. Do not
  silently change roles or scope.

## Build the batch

Delegate work that has a clear boundary and remains useful on its own. Prefer
assigning the actual implementation or validation, not a read-only report that
leaves the root to repeat the same work. Give every worker:

- one concrete objective and an observable done condition;
- the exact project root or paths in scope;
- explicit ownership of the files, directories, or output artifacts it may edit;
- permission to inspect dependencies and run safe, relevant local validation;
- required evidence and output format;
- relevant constraints from the user and `AGENTS.md`;
- a reminder that other agents may be working in the same checkout, so it must
  preserve unrelated changes and accommodate concurrent edits.

Respect the current runtime's concurrency and nesting limits. Start clearly
independent tasks together, but reserve capacity for follow-up and review.
Prefer a few well-partitioned assignments over duplicate investigations.

## Protect shared work

- Inspect the existing worktree before assigning writes so user changes and
  concurrent ownership are visible.
- Multiple workers may inspect the same project, and may write concurrently
  when ownership is partitioned by project, disjoint paths, or distinct output
  artifacts.
- Never assign overlapping writes in one checkout. If overlap is unavoidable,
  serialize the assignments or use isolated worktrees when that is already
  authorized and appropriate.
- Workers must not commit, submit, deploy, delete, or perform other external or
  destructive actions unless the user explicitly authorized that action.
- Do not redo a worker's assignment in the root while it is running. Continue
  orchestration, dependency analysis, or integration work that does not
  duplicate its ownership.
- Do not treat a worker's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.

## Integrate

Track each assignment through completion. Follow up with the same worker when
its context is valuable; use a separate reviewer when independence adds value.
Integrate worker outputs, make the remaining cross-cutting decisions, and fix
only small integration gaps directly; delegate substantial rework back with a
revised boundary and acceptance condition.
Before reporting completion, account for every assignment as accepted,
superseded, failed, or cancelled, then give one root-level conclusion.
