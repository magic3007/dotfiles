---
name: toil-offloading-omp
description: "Orchestrate decomposable workloads with omp subagents: the root agent analyzes, decides, partitions, integrates, and accepts while subagents execute bounded investigation, implementation, testing, and repetitive work. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (omp)

The orchestration contract — what stays in the root, how to partition, the
8-field assignment brief, risk-based validation, and integration — is
harness-neutral and lives in `~/.agents/skills/toil-offloading/SKILL.md` and
`~/.agents/skills/toil-offloading/references/assignment-brief.md`. Read both
before the first delegation. This skill adds only what omp decides.

A weak model is dangerous when it must *decide* and safe when it must *execute*.
The contract, not the model, carries the reasoning — that is why the assignment
brief is the part of this skill that actually governs quality.

## Spawn

Spawn through omp's native spawners: the `task` tool, and in Eval sessions
`agent()` / `workpool()`. Never launch agent CLIs (`claude`, `codex`, `omp -p`,
`gemini`, …) as shell subprocesses, and never fake a worker with `bash`.

Children start blank and do not see this conversation. Collect background
results with `read agent://<id>` or `wait`; pass large payloads through
`local://<path>`, never inline.

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

## Route

- Select agents from the runtime's advertised list by task complexity, cost, and
  the evidence the assignment must produce.
- Prefer the default `task` agent for targeted searches, inventories,
  extraction, formatting, repetitive validation, focused test execution, and
  small independent edits with an obvious acceptance condition.
- Omit `agent` for the default. Put specialist selectors inside each `tasks[]`
  item, never at the top level.
- Prefer a stronger model, as a stated per-task `model` override, for cross-file
  analysis, ambiguous diagnosis, non-trivial implementation, conflict analysis,
  or independent review.

## Concurrency and isolation

Runtime facts (concurrency, nesting, batch) live in `omp/README.md`, "Subagent
档位". Read them before the first spawn of a session; the spawn tool's own
description stays authoritative for the live limits.

`isolated: true` fails preflight while `task.isolation.enabled` is false, and
when enabled it applies successful changes back to the parent checkout
(`task.isolation.apply` defaults to true). Only reach for it when the
partitioning cannot be fixed and the user authorized branching work.

Agents share the parent checkout. One integration owner runs build, lint, test,
and formatters after the batch, not each worker mid-flight.
