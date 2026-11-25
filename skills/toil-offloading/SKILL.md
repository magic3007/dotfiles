---
name: toil-offloading
description: |
  Harness-neutral orchestration rules and the 8-field assignment brief shared by the
  per-harness toil-offloading skills (`toil-offloading-codex`, `toil-offloading-omp`,
  `toil-offloading-pi`). Read it from one of those skills before the first delegation;
  do not invoke it directly, because spawning a subagent needs the harness skill's
  runtime section.
---

# Toil Offloading

Keep the root agent as orchestrator, not the default implementer. The root owns
goal clarification, decomposition, cross-cutting analysis, architectural and
priority decisions, assignment boundaries, conflict resolution, integration, and
final acceptance. Delegate the bounded execution work: repository searches,
diagnosis, implementation, refactoring, data extraction, artifact generation,
and focused verification.

Subagents are not read-only by default. Give them the write scope and local
validation needed to finish their assignments. Use read-only assignments only
when the work is genuinely inspection-only, the user requested it, or write
isolation cannot be made safe.

This skill holds what every harness shares. Which tool spawns a subagent, which
agent types or model tiers exist, the concurrency limits, and the isolation
mechanics belong to the harness skill that referred you here.

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the agents the runtime advertises as the session
contract and send the first useful assignments directly. If an assignment cannot
start or finish, record its actual outcome and continue other safe, useful work.
Reassign only when the scope and acceptance condition stay explicit; never
replace a worker with a shell subprocess.

## Partition

Cut by **what can stand alone**, not by what is easy. A contract may cover:

| Contract type | Work |
|---|---|
| Recon | Locating code, tracing dependencies, gathering context the root has not seen |
| Planning | Converting settled context and requirements into an ordered plan |
| Implementation | Implementation, refactoring, migration, batch edits, artifacts, tests, focused suite runs |
| Review | Independent read-only review of a delivered change against its acceptance criteria |

Keep in the root:

- Requirement clarification and any genuine ambiguity in the goal.
- Architecture, interface, and design trade-off calls — the decisions a
  contract is supposed to encode.
- Risk grading and the accept/rework verdict.
- Conflict resolution, destructive or externally mutating actions, final
  integration.

Do not delegate a decision and call it "investigation": if the root does not
know the answer, decide it first, then delegate execution of that decision. The
one legitimate exception is context gathering — a recon child may return facts
the root then reasons over. That is retrieval, not judgment.

Design the slices in the root before dispatch: which files each slice owns,
which interfaces must agree, and the observable acceptance condition for each.
Prefer a few well-partitioned assignments over duplicate investigations, and
reserve capacity for follow-up and review.

## Write the contract

The assigning agent owns instruction quality. Do not send a one-line goal such
as "fix the tests" or "analyze this module" and expect the worker to reconstruct
the requirements, discover hidden constraints, or make architectural decisions.
Children start blank and do not see the root's conversation, so the brief must
stand alone.

Read enough source material to establish a sound boundary and starting point
before assigning, without completing the worker's investigation. Distinguish
verified facts, hypotheses to test, and unresolved questions. Do not invent file
paths, APIs, commands, or expected results to make a brief look complete. If the
implementation path is unknown, delegate a bounded investigation with explicit
questions and evidence requirements before assigning the edit.

The fields every brief carries, with concrete values instead of placeholders,
are in `~/.agents/skills/toil-offloading/references/assignment-brief.md`.

## Validate by risk

Cheap generation makes independent checking worth more, not less. Grade the
delivery and match the check to it.

| Risk | Signals | Check |
|---|---|---|
| **Low** | Formatting, renames, doc/index updates, mechanical sweeps, no behavior change | Root inspects the diff or artifact directly |
| **Medium** | Contained behavior change, new code behind clear tests, additive migrations | Root runs the focused suite; add a review contract when the change is too large for the root to re-read |
| **High** | Security, auth, data mutation or deletion, concurrency, money/permissions, changes that are expensive or impossible to reverse | A review contract against the written acceptance criteria, plus root verification |

Verification depth tracks **blast radius**, not diff size: a one-line permission
check outranks a 500-line rename. A clean review is not acceptance — the root
owns the verdict.

## Protect shared work

- Inspect the worktree before assigning writes so user changes and concurrent
  ownership are visible.
- Partition contracts so parallel writes never overlap: by project, disjoint
  paths, or distinct output artifacts.
- Never assign overlapping writes in one checkout. If overlap is unavoidable,
  serialize those contracts.
- Workers must not commit, submit, deploy, delete, or perform other external or
  destructive actions unless the user explicitly authorized that action.
- Do not redo a worker's assignment in the root while it runs. Continue
  orchestration, dependency analysis, or integration work that does not
  duplicate its ownership.
- Do not treat a worker's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.

## Integrate and accept

Track every contract to completion. Re-read each result as **claims, not
conclusions**: check the diff or artifacts against each acceptance criterion, and
reconcile any report that disagrees with what is on disk.

Fix small integration gaps directly in the root. For substantial rework, issue a
revised contract with a new boundary and acceptance condition rather than
patching silently.

Before reporting completion, account for every contract as accepted, superseded,
failed, or cancelled, then give one root-level conclusion.
