---
name: toil-offloading
description: "Orchestrate decomposable workloads with omp subagents: the root agent analyzes, decides, partitions, integrates, and accepts while subagents execute bounded investigation, implementation, testing, and repetitive work. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (omp)

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

Spawn through omp's native spawners: the `task` tool, and in Eval sessions
`agent()` / `workpool()`. Never launch agent CLIs (`claude`, `codex`, `omp -p`,
`gemini`, …) as shell subprocesses, and never fake a worker with `bash`.

A weak model is dangerous when it must *decide* and safe when it must *execute*.
The contract, not the model, carries the reasoning — that is why the assignment
brief below is the part of this skill that actually governs quality.

## Tiers

| Tier | Model | Owns |
|---|---|---|
| Root | session model (defaults to `modelRoles.default`) | Goal, decomposition, design calls, contract authorship, integration, acceptance |
| Subagent | default `task` agent → `modelRoles.task` (whatever the user configures) | Executing contracts: recon, implementation, refactoring, extraction, artifact generation, test writing, slice-local checks |

The tier is one session-wide setting, not a per-assignment choice: the bundled
`task` agent declares `model: "@task"`, so default spawns resolve through
`modelRoles.task` in `omp/config.yml`. Change that role to change the tier.

Upgrades are exceptions the root decides and states in the contract:

- `model` on one `tasks[]` item wins over the agent definition — use it for a
  slice the cheap tier cannot do (cross-file diagnosis, non-trivial design,
  independent review). Do not override by default.
- `sonic` resolves to `@smol` and `scout` is read-only. They are agents, not
  cheaper models; check what role they resolve to before using them.

Runtime facts (concurrency, nesting, batch) live in `omp/README.md`, "Subagent
档位". Read them before the first spawn of a session; the spawn tool's own
description stays authoritative for the live limits.

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the agents the runtime advertises as the session
contract and send the first useful assignments directly. If an assignment
cannot start or finish, record its actual outcome and continue other safe,
useful work. Reassign only when the scope and acceptance condition stay
explicit; never replace a worker with a shell subprocess.

## Route work

- Select agents from the runtime's advertised list by task complexity, cost,
  and the evidence the assignment must produce.
- Prefer the default `task` agent for targeted searches, inventories,
  extraction, formatting, repetitive validation, focused test execution, and
  small independent edits with an obvious acceptance condition.
- Omit `agent` for the default. Put specialist selectors inside each
  `tasks[]` item, never at the top level.
- Prefer a stronger model, as a stated per-task `model` override, for
  cross-file analysis, ambiguous diagnosis, non-trivial implementation,
  conflict analysis, or independent review.
- Keep architectural decisions, destructive or externally mutating actions,
  conflict resolution, final integration, and acceptance with the root agent.
- Let workers make ordinary implementation decisions inside their contract.
  Require them to return cross-cutting choices or scope changes to the root
  instead of silently expanding the assignment.
- If an assignment exposes materially different complexity, finish or close it,
  then create a new bounded assignment with a suitable agent. Never silently
  change roles or scope.

## Build the batch

Before spawning, map the slices and the shared contracts: which files each
slice owns, which interfaces must agree, and the observable acceptance
condition for each. Design the slices in the root; only execution is delegated.

Delegate work that has a clear boundary and remains useful on its own. Prefer
assigning the actual implementation or validation, not a read-only report that
leaves the root to repeat the same work. Prefer a few well-partitioned
assignments over duplicate investigations, and reserve capacity for follow-up
and review.

Children start blank and do not see this conversation. Collect background
results with `read agent://<id>` or `wait`; pass large payloads through
`local://<path>`, never inline.

## Prepare detailed assignment instructions

The assigning agent owns instruction quality. Do not send a one-line goal such
as "fix the tests" or "analyze this module" and expect a cheap worker to
reconstruct the requirements, discover hidden constraints, or make
architectural decisions. Write a self-contained brief even when the child would
inherit a fork. Assume the worker needs explicit guidance; more detail should
remove ambiguity, not bury the task in unrelated history.

This applies to initial assignments, follow-ups, reassignments, and any
delegation performed by a worker inside its own scope.

Read enough source material to establish a sound boundary and starting point
before assigning, without completing the worker's investigation. Distinguish
verified facts, hypotheses to test, and unresolved questions. Do not invent
file paths, APIs, commands, or expected results to make a brief look complete.
If the implementation path is unknown, delegate a bounded investigation with
explicit questions and evidence requirements first.

Include all applicable fields in the actual assignment, with concrete values
rather than unfilled placeholders:

1. **Objective and context:** the user-visible outcome, why this subtask is
   needed, the current behavior or evidence, and its relation to the parent
   task. Carry forward exact user criteria, terminology, and prior decisions.
2. **Inputs and starting points:** absolute working directory, input paths or
   identifiers, relevant source files and symbols, and the specific
   instructions or documentation to read first. Name the source of truth and
   whether prerequisites are ready.
3. **Ownership and limits:** the files, directories, or artifacts the worker
   may change; what it may only inspect; explicit exclusions. State the user
   instructions and `AGENTS.md` constraints, and the allowed validation or side
   effects. Tell it: "You are not alone in the codebase. Preserve unrelated
   changes and accommodate concurrent edits; do not revert others' work."
4. **Execution steps:** an ordered, task-specific procedure: where to start,
   what to inspect or change, which existing APIs or patterns to reuse, how
   dependencies connect. Resolve cross-cutting design choices in the root.
   Specify invariants, likely pitfalls, and relevant edge cases.
5. **Input/output contract:** required artifact paths, formats, fields, types,
   units, stable keys, or matching rules. Include a representative example and
   a boundary or negative example when a rule is easy to misread. Preserve
   exact literals when exact matching matters.
6. **Verification and acceptance:** observable pass/fail criteria and the
   focused checks or inspection procedure, including working directory and
   expected behavior. Name the commands that must be run in the assignment's
   own slice, and those that integration will run once. State which evidence to
   retain. A successful command or completion message alone is not proof that
   the requested result is correct.
7. **Blockers and escalation:** what to do if inputs are absent, source
   material contradicts the brief, validation fails, or completion needs
   changes outside ownership. Require the worker to report the concrete
   evidence and the decision needed to the assigning agent, preserve completed
   work, and pause dependent actions instead of guessing, broadening scope,
   weakening checks, or claiming success. Independent in-scope work may
   continue.
8. **Return format:** a concise summary, changed file or artifact paths,
   results against each acceptance criterion, checks actually run with
   outcomes, and remaining uncertainties or blockers. Separate verified facts
   from assumptions and explicitly mark checks that were not run.

Before sending, check whether a worker with only this brief and the referenced
materials can determine what to do, where to do it, what to avoid, how to
verify it, and when to stop. Fill any gap first. For a cheap worker, prefer
smaller steps, explicit commands where they are known, and concrete examples,
rather than asking it to compensate for an underspecified task. A detailed
brief does not replace routing work the cheap tier cannot do to a stronger
model.

Follow-ups may reference an existing contract in the same worker's context, but
must spell out the observed failure, the required correction, and the
acceptance criteria that still apply. A replacement worker needs the complete
current brief and the relevant evidence; never forward only "continue" or "try
again".

## Protect shared work

- Inspect the existing worktree before assigning writes, so user changes and
  concurrent ownership are visible. Agents share the parent checkout.
- Multiple workers may inspect the same project, and may write concurrently
  when ownership is partitioned by project, disjoint paths, or distinct output
  artifacts.
- Never assign overlapping writes in one checkout. If overlap is unavoidable,
  serialize the assignments. One integration owner runs build, lint, test, and
  formatters after the batch, not each worker mid-flight.
- `isolated: true` fails preflight while `task.isolation.enabled` is false, and
  when enabled it applies successful changes back to the parent checkout
  (`task.isolation.apply` defaults to true). Only reach for it when the
  partitioning cannot be fixed and the user authorized branching work.
- Workers must not commit, submit, deploy, delete, or take other external or
  destructive actions unless the user explicitly authorized that action.
- Do not redo a worker's assignment in the root while it runs. Continue
  orchestration, dependency analysis, or integration work that does not
  duplicate its ownership.
- Do not treat a worker's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.

## Integrate

Track each assignment through completion: `read agent://<id>` for background
spawns, `wait` when the root is blocked. Follow up with the same worker when its
context is valuable; use a separate reviewer when independence adds value.
Integrate worker outputs, make the remaining cross-cutting decisions, then run
the build, lint, test, and formatter pass once for the batch. Fix only small
integration gaps directly; delegate substantial rework back with a revised
boundary and acceptance condition. Before reporting completion, account for
every assignment as accepted, superseded, failed, or cancelled, then give one
root-level conclusion.
