---
name: toil-offloading-pi
description: "Orchestrate decomposable workloads with pi subagents (afang-subagent extension): the root agent analyzes, decides, partitions, integrates, and accepts while subagents execute bounded investigation, implementation, testing, and repetitive work. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (pi)

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

Use the `subagent` tool exposed by the `afang-subagent` extension. Do not launch
agent CLIs (claude, codex, gemini, ...) as shell subprocesses.

## pi runtime constraints

These differ from the Codex native-team model and are hard limits — design the
batch around them:

- **Modes**: single (`{agent, task}`), parallel (`{tasks: [...]}`, max 8 tasks,
  4 concurrent), chain (`{chain: [...]}`, sequential with `{previous}`),
  background (`{agent, task, background: true, topic?}`, max 4 concurrent,
  returns `task-N` immediately).
- **No nested delegation.** The main session is depth 0; a spawned subagent is
  depth 1 and does **not** register the `subagent` tool. A worker cannot
  delegate further — never write an assignment that assumes it will.
- **Model inheritance**: a subagent with no `model:` in its frontmatter inherits
  the current session model (`ctx.model`, including after `/model`).
- **Built-in agents** (bundled in the extension, always available):

  | Agent | Purpose |
  |---|---|
  | `scout` | Fast codebase recon returning compressed context |
  | `planner` | Implementation plans |
  | `reviewer` | Code review |
  | `worker` | General-purpose, full capabilities |

- **External-API agents** (installed at `~/.pi/agent/agents/`, run on other
  providers so toil does not consume the main session's model budget):

  | Agent | Backend | Route to it for |
  |---|---|---|
  | `dspix` | DeepSeek Flash (`dspro-responses/deepseek-flash`) | mechanical / retrieval / formatting work |
  | `glmpix` | GLM-5.3-Flash (`zai-responses/glm-5.3-flash`) | diagnosis / reasoning / review work |

  Both require their API keys in the environment (`DEEPSEEK_API_KEY`,
  `ZAI_API_KEY`). Their frontmatter carries the full `provider/model-id` because
  the pi runtime passes the value straight to `--model` and never emits
  `--provider` separately — a bare model id would resolve against the wrong
  provider.

  Run `subagent {}` to list what is actually available at runtime (includes
  user-level overrides); `subagent {agentScope: "both"}` adds project agents.
- **Monitoring**: `/subagent` (alias `/sa`) opens a panel to watch each child's
  trajectory and kill individuals without aborting the whole batch. The
  `subagent_tasks` tool (`list` / `status` / `result` / `cancel`) covers both
  foreground live and background tasks.
- Background results land in `<task cwd>/.pi/subagent-results/<timestamp>-<task-id>-<slug>.md`
  (falls back to `~/.pi/agent/subagent-results/` when not writable).

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the agent types advertised by the runtime as the
session contract and send the first useful assignments directly. If an
assignment cannot start or finish, record its actual outcome and continue other
safe, useful work. Reassign only when the task scope and acceptance condition
remain explicit; never replace a subagent with a shell subprocess.

## Route work

### Select by task nature

The root agent makes this call itself. Pick the first rule that matches — the
basis is the **nature of the work**, not its size. A big-but-mechanical job
(formatting 50 files) goes to `dspix`; a small-but-reasoning job (what is the
root cause of this error) goes to `glmpix`.

| Work | Agent |
|---|---|
| Targeted search, file inventory, field extraction, format conversion, batch rename, repetitive checks, small independent edits, running an existing test suite | `dspix` |
| Root-cause diagnosis, ambiguous bug, cross-file analysis, implementation trade-offs, independent code review, conflict analysis | `glmpix` |
| Unclear, needs the full toolset or long shared context | `worker` (inherits the main session model) |
| Fast recon returning compressed context | `scout` |
| Producing an implementation plan | `planner` |
| Independent review with the main model's perspective | `reviewer` |

Prefer `dspix` and `glmpix` for decomposable toil: they run on separate
provider budgets, so offloading there preserves the main session's context and
cost. Reach for `scout` / `planner` / `worker` / `reviewer` when the task needs
the main model's full context or toolset, or when a second model's independent
view adds value (`glmpix` and `reviewer` overlap deliberately — different
models, different blind spots).

### Escalate, do not retry

If `dspix` reports the task is out of mechanical scope, or fails in a way that
shows it needs reasoning, do not retry it there. Take its evidence and re-route
the same bounded task to `glmpix`. Likewise, if `glmpix` exposes an
execution-shaped remainder after reaching its conclusion, split that remainder
out and send it back to `dspix`.

### Additional routing rules

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
leaves the root to repeat the same work. Before dispatch, prepare the detailed
assignment contract below. This applies to initial assignments, follow-ups,
reassignments, and any delegation by a worker.

Respect the pi concurrency limits (8 parallel tasks / 4 concurrent; 4 background).
Start clearly independent tasks together, but reserve capacity for follow-up
and review. Prefer a few well-partitioned assignments over duplicate
investigations.

## Prepare detailed assignment instructions

The assigning agent owns instruction quality. Do not send a one-line goal such
as "fix the tests" or "analyze this module" and expect the worker to reconstruct
the requirements, discover hidden constraints, or make architectural decisions.
Write a self-contained execution brief even when conversation history is forked.
Assume the worker needs explicit guidance to execute reliably; do not rely on
its ability to infer missing requirements. More detail should remove ambiguity,
not bury the task in unrelated history.

Read enough source material to establish a sound boundary and starting point
before assigning the task, without completing the worker's investigation.
Distinguish verified facts, hypotheses to test, and unresolved questions. Do not
invent file paths, APIs, commands, or expected results to make a brief look
complete. If the implementation path is unknown, delegate a bounded investigation
with explicit questions and evidence requirements before assigning the edit.

Include all applicable fields in the actual assignment message, with concrete
values rather than unfilled placeholders:

1. **Objective and context:** Explain the user-visible outcome, why this subtask
   is needed, the current behavior or evidence, and its relation to the parent
   task. Carry forward exact user criteria, terminology, and prior decisions.
2. **Inputs and starting points:** Supply the absolute working directory, input
   paths or identifiers, relevant source files and symbols, and the specific
   instructions or documentation to read first. Identify the source of truth
   and any prerequisite artifacts; say whether they are ready.
3. **Ownership and limits:** List the files, directories, or output artifacts
   the worker may change, what it may only inspect, and explicit exclusions.
   State relevant user and `AGENTS.md` constraints and allowed validation or
   side effects. Tell it: "You are not alone in the codebase. Preserve unrelated
   changes and accommodate concurrent edits; do not revert others' work."
   Note that it cannot delegate further.
4. **Execution steps:** Give an ordered, task-specific procedure: where to
   start, what to inspect or change, which existing APIs or patterns to reuse,
   and how dependencies connect. Resolve cross-cutting design choices in the
   root. Specify invariants, likely pitfalls, and relevant edge cases. Leave
   ordinary implementation choices open only within these explicit boundaries.
5. **Input/output contract:** Define required artifact paths, formats, fields,
   types, units, stable keys, or matching rules where relevant. Include a
   representative example and a boundary or negative example when a rule is
   easy to misinterpret. Preserve exact literals when exact matching matters.
6. **Verification and acceptance:** Provide observable pass/fail criteria and
   the focused tests, commands, or inspection procedure, including working
   directory and expected behavior. State which checks must actually run and
   which evidence to retain. A successful command or completion message alone
   is not proof that the requested result is correct.
7. **Blockers and escalation:** State what to do if inputs are absent, source
   material contradicts the brief, validation fails, or completion requires
   changes outside ownership. Require the worker to report the concrete
   evidence and decision needed to the assigning agent, preserve completed
   work, and pause dependent actions instead of guessing, broadening scope,
   weakening checks, or claiming success. Independent in-scope work may continue.
8. **Return format:** Require a concise summary, changed file or artifact paths,
   results against each acceptance criterion, checks actually run with outcomes,
   and remaining uncertainties or blockers. Separate verified facts from
   assumptions and explicitly mark checks that were not run.

Before sending, check whether a worker with only this brief and the referenced
materials can determine what to do, where to do it, what to avoid, how to verify
it, and when to stop. Fill any gap first. For lightweight workers such as
`scout`, use smaller steps, explicit commands where known, and concrete examples
rather than asking them to compensate for an underspecified task. A detailed
brief does not replace routing complex work to a suitably capable agent.

Follow-ups may reference the existing contract in the same worker's context,
but must spell out the observed failure, required correction, and acceptance
criteria that still apply. A replacement worker needs the complete current
brief and relevant evidence; do not forward only "continue" or "try again".

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
