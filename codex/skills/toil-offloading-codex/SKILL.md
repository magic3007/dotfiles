---
name: toil-offloading-codex
description: "Orchestrate decomposable workloads with native Codex team agents: the root agent analyzes, decides, partitions, integrates, and accepts while subagents execute bounded investigation, implementation, testing, and repetitive work. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (Codex)

The orchestration contract — what stays in the root, how to partition, the
8-field assignment brief, risk-based validation, and integration — is
harness-neutral and lives in `~/.agents/skills/toil-offloading/SKILL.md` and
`~/.agents/skills/toil-offloading/references/assignment-brief.md`. Read both
before the first delegation. This skill adds only what Codex decides.

## Runtime

Use only the native collaboration tools exposed by the current Codex runtime. Do
not launch agent CLIs or `codex exec` as shell subprocesses.

## Choose the agent type

- Select agent types from the runtime descriptions by task complexity, cost, and
  the evidence the assignment must produce.
- Prefer lightweight worker roles for targeted searches, inventories,
  extraction, formatting, repetitive validation, focused test execution, and
  small independent edits with an obvious acceptance condition.
- Prefer stronger reasoning roles for cross-file analysis, ambiguous diagnosis,
  non-trivial implementation, conflict analysis, or independent review.
- If an assignment exposes materially different complexity, finish or close it
  and create a new bounded assignment with a suitable agent type. Do not
  silently change roles or scope.

Respect the runtime's concurrency and nesting limits. Start clearly independent
tasks together, and reserve capacity for follow-up and review.
