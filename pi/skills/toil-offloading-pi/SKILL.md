---
name: toil-offloading-pi
description: "Orchestrate decomposable workloads with pi subagents (pi-herdr-agents extension): the strong-but-slow root agent clarifies goals, cuts the work into contract-bearing subtasks, fans them out to cheap-and-fast subagents, grades delivery risk, runs an independent review where it pays, and accepts the result. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (pi)

The orchestration contract — what stays in the root, how to partition, the
8-field assignment brief, risk-based validation, and integration — is
harness-neutral and lives in `~/.agents/skills/toil-offloading/SKILL.md` and
`~/.agents/skills/toil-offloading/references/assignment-brief.md`. Read both
before the first delegation. This skill adds only what pi decides.

The root agent is the strong, slow model. Subagents are cheap and fast. Design
the work so the expensive model spends its budget on judgment, and the cheap
models absorb volume.

Use the `subagent` tool exposed by the `pi-herdr-agents` extension. Do not launch
agent CLIs (claude, codex, gemini, ...) as shell subprocesses.

Runtime mechanics — launch parameters, supervision, worktrees, config keys — are
owned by the package's operating guide: `/skill:pi-herdr-agents` plus the
package docs under
`~/.pi/agent/npm/node_modules/pi-herdr-agents/docs/`.

## The two-tier model

| Tier | Model | Owns |
|---|---|---|
| **Root** | the session's strong/slow model | Goal clarification, decomposition, architecture and design calls, contract authorship, integration, risk grading, acceptance |
| **Subagents** | cheap/fast (`models.default`, a role's pinned model, or the per-call `model`) | Executing contracts: recon, implementation, refactoring, data extraction, artifact generation, test writing, verification runs, review |

Delegation is the default for decomposable work because the marginal subtask
costs a cheap model's time, not the root's. The root should spend its context on
the plan and the acceptance decision, not on typing out the changes.

### Where the tier is declared

`~/.pi/agent/herdr-agents/config.json` holds the durable defaults, and the
checked-in source of that file is `pi/herdr-agents/config.json` in the dotfiles
repository (the seed hook copies it only when the target is missing). The
relevant key is `models.default`; per-role pins live in role frontmatter and
per-task overrides in the tool call.

Resolution order for a child's model: the `model` parameter → the role's
frontmatter `model:` → `models.agents.<name>` → `models.default` → the parent
model. Set the cheap tier in one place (`models.default`, or a role that most
contracts use) instead of repeating it in every call. Pinning the same tier in
two places creates a second source of truth that silently loses.

The file is read at extension startup, so `/reload` after editing it.

## Runtime constraints that shape the design

- **Launches are asynchronous.** `subagent` returns an acknowledgement and the
  child's result arrives later as its own message. Fan-out is N independent
  calls, not one batch object, and there are no `parallel` / `chain` /
  `background` modes to choose between: every launch is already background.
- **Never poll.** Do not sleep, tail session files, run watch loops, or call
  `subagents_list` to check progress. The runtime delivers each result as its own
  turn. A `stalled` or no-progress notice is a fact to read, not an instruction
  to act.
- **No nested delegation.** Children are leaves by default and do not get the
  `subagent` tool. State in the contract that the child cannot delegate further.
- **Per-child model and thinking are part of the contract surface.** A call may
  pin `model` (a `provider/model-id`, a comma-separated fallback list, or
  `task:<category>`) and `thinking`. Use it when one subtask genuinely needs a
  stronger tier; put the pin in the call, not in prose the child must interpret.
- **Roles are optional.** A bare `subagent({ name, task })` always works. A named
  `agent` resolves from `.pi/agents/`, then `~/.pi/agent/agents/`, then installed
  role packs, and a missing or invalid role fails before any pane is created. The
  package ships no roles. Run `subagents_list` (or `/subagent list`) before
  relying on a name.
- **Results are bounded.** A result longer than 16,000 characters is shortened in
  the parent context; the full text stays in the child session. Require a return
  format that survives truncation: verdict and evidence first, prose last.
- **Worktrees are opt-in per launch.** Use one managed worktree per parallel,
  independent writer; a single sequential writer can work in the parent checkout.
  The base is the committed `HEAD`, so uncommitted parent changes are not copied.
  The extension never pushes, merges, or removes a worktree on its own — cleanup
  is an explicit `worktree_remove` by the root. A worktree child may commit when
  the contract says so, and keeps the branch unpushed.
- **Persistent specialists** (`persistent: true`) keep one policy-bound session
  for sequential turn-based work; send follow-ups with `subagent_send`. They
  cannot be resumed. Use them for a long-running reviewer the root revisits, not
  for one-shot contracts.
- **Control tools**: `subagent_interrupt` stops one turn and keeps the session,
  `subagent_cancel` ends an ordinary run, `subagent_stop` retires a persistent
  specialist, `subagent_resume` continues an exited child session. Do not poll
  after a cancel or stop; the outcome arrives as a message.
- **Children can ask the parent for help** with `caller_ping`. A help request is
  a contract defect or a real ambiguity — answer it with the missing decision,
  then continue, rather than restarting the child.

## Choosing when to fan out

- **Do** launch independent contracts together; each returns on its own.
- **Do not** launch a child whose result the root must have before it can write
  the next contract. Decide, write the next contract, then launch — sequential
  dependencies are the root's job, not a chain the runtime performs.
- **Do not** launch work the root will immediately duplicate while waiting. If
  the root has nothing independent to do, the task was not worth delegating.

## The reviewer's real job

A review child runs on the cheap tier with read-only tools. Two consequences:

- **It is a second pass over the acceptance criteria, not an oracle.** Give it
  the criteria and the changed paths, and ask for specific findings with file
  and line numbers. It is good at catching "the contract said X and the code
  does Y", missing edge cases, and obvious defects.
- **A cheap reviewer cannot out-reason the root.** When a high-risk change needs
  judgment the cheap model may not be trusted with, the root does the deep
  review itself; the review contract is an additional sweep for concrete
  discrepancies, not a substitute for the root's verdict.

Launch the review child in a fresh session (`fork: false`) when you need
context-isolated review. Cross-family independence, when it matters, means
pinning a `model` from a different family than the author — a fresh session alone
does not provide it.

## Accept

Re-read each result as claims, not conclusions: check the diff or artifacts
against each acceptance criterion, and reconcile any report that disagrees with
what is on disk. Follow up with the same child when its context is valuable, or
resume an exited child with `subagent_resume` rather than starting over. Retained
worktrees are part of the delivery: list them with `worktree_list` and remove
them with `worktree_remove` once their content is integrated.
