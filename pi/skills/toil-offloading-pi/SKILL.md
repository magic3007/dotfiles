---
name: toil-offloading-pi
description: "Orchestrate decomposable workloads with pi subagents (pi-herdr-agents extension): the strong-but-slow root agent clarifies goals, cuts the work into contract-bearing subtasks, fans them out to cheap-and-fast subagents, grades delivery risk, runs an independent review where it pays, and accepts the result. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
---

# Toil Offloading (pi)

The root agent is the strong, slow model. Subagents are cheap and fast. Design
the work so the expensive model spends its budget on judgment, and the cheap
models absorb volume.

The test is **not** "is this mechanical?" — it is **"can this be cut off as a
self-contained subtask with an observable acceptance condition?"** If yes, it can
be delegated, including implementation, refactoring, and writing tests. What
stays with the root is the part that cannot be written down as a contract
because it *is* the decision: which design is right, what the real requirement
is, and whether the delivered work is acceptable.

Use the `subagent` tool exposed by the `pi-herdr-agents` extension. Do not launch
agent CLIs (claude, codex, gemini, ...) as shell subprocesses.

Runtime mechanics — launch parameters, supervision, worktrees, config keys — are
owned by the package's operating guide: `/skill:pi-herdr-agents` plus the
package docs under
`~/.pi/agent/npm/node_modules/pi-herdr-agents/docs/`. This skill owns *what to
delegate and how to write the contract*; it does not restate the tool reference.

## The two-tier model

| Tier | Model | Owns |
|---|---|---|
| **Root** | the session's strong/slow model | Goal clarification, decomposition, architecture and design calls, contract authorship, integration, risk grading, acceptance |
| **Subagents** | cheap/fast (`models.default`, a role's pinned model, or the per-call `model`) | Executing contracts: recon, implementation, refactoring, data extraction, artifact generation, test writing, verification runs, review |

Delegation is the default for decomposable work because the marginal subtask
costs a cheap model's time, not the root's. The root should be spending its
context on the plan and the acceptance decision, not on typing out the changes.

### Where the tier is declared

`~/.pi/agent/herdr-agents/config.json` holds the durable defaults, and the
checked-in source of that file is `~/dotfiles/pi/herdr-agents/config.json`
(the seed hook copies it only when the target is missing). The relevant key is
`models.default`; per-role pins live in role frontmatter and per-task overrides
in the tool call.

Resolution order for a child's model: the `model` parameter → the role's
frontmatter `model:` → `models.agents.<name>` → `models.default` → the parent
model. Set the cheap tier in one place (`models.default`, or a role that most
contracts use) instead of repeating it in every call. Pinning the same tier in
two places creates a second source of truth that silently loses.

The file is read at extension startup, so `/reload` after editing it.

### Why cheap subagents are safe here

A weak model is dangerous when it must *decide* and safe when it must *execute*.
So the contract, not the model, carries the reasoning: confirm the approach in
the root, write it down concretely, and let the subagent do the volume. This is
why contract quality is the single most important thing this skill governs. A
vague contract handed to a cheap model produces a confident guess, which is
worse than no delegation.

## Runtime constraints that shape the design

- **Launches are asynchronous.** `subagent` returns an acknowledgement and the
  child's result arrives later as its own message. Fan-out is therefore N
  independent calls, not one batch object, and there are no `parallel` / `chain`
  / `background` modes to choose between: every launch is already background.
- **Never poll.** Do not sleep, tail session files, run watch loops, or call
  `subagents_list` to check progress. The runtime delivers each result as its own
  turn. A `stalled` or no-progress notice is a fact to read, not an instruction
  to act.
- **No nested delegation.** Children are leaves by default and do not get the
  `subagent` tool. Never write a contract that assumes the child will delegate
  further.
- **Per-child model and thinking are part of the contract surface.** A call may
  pin `model` (a `provider/model-id`, a comma-separated fallback list, or
  `task:<category>`) and `thinking`. Use it when one subtask genuinely needs a
  stronger tier; put the pin in the call, not in prose the child must interpret.
- **Roles are optional.** A bare `subagent({ name, task })` always works. A named
  `agent` resolves from `.pi/agents/`, then `~/.pi/agent/agents/`, then installed
  role packs, and a missing or invalid role fails before any pane is created. The
  package ships no roles. Run `subagents_list` (or `/subagent list`) before
  relying on a name; this machine currently defines `dspix`.
- **Results are bounded.** A result longer than 16,000 characters is shortened in
  the parent context; the full text stays in the child session. Require a return
  format that survives truncation: verdict, paths, criteria-by-criteria results,
  and evidence first, prose last.
- **Worktrees are opt-in per launch.** Use one managed worktree per parallel,
  independent writer; a single sequential writer can work in the parent
  checkout. The base is the committed `HEAD`, so uncommitted parent changes are
  not copied. The extension never pushes, merges, or removes a worktree on its
  own — cleanup is an explicit `worktree_remove` by the root.
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

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the advertised tool and role set as the session
contract and send the first useful contracts directly. If a subagent cannot start
or finish, record its actual outcome and continue other safe, useful work.
Reassign only when the scope and acceptance condition remain explicit; never
replace a subagent with a shell subprocess.

## Partition

Cut by **what can stand alone**, not by what is easy.

| Contract type | Work |
|---|---|
| Recon | Locating code, tracing dependencies, gathering context the root has not seen |
| Planning | Converting settled context and requirements into an ordered plan |
| Implementation | Implementation, refactoring, migration, batch edits, artifacts, test writing, running the focused suite |
| Review | Independent read-only review of a delivered change against its acceptance criteria |

These are contract shapes, not required agent names. Name a role only when one
already exists for it.

Keep in the root:

- Requirement clarification and any genuine ambiguity in the goal.
- Architecture, interface, and design trade-off calls — the decisions a contract
  is supposed to encode.
- Risk grading and the accept/rework verdict.
- Conflict resolution, destructive or externally mutating actions, final
  integration.

Do not delegate a decision and call it "investigation" — if the root does not
know the answer, decide it first, then delegate execution of that decision. The
one legitimate exception is *context gathering*: a recon child may return facts
the root then reasons over. That is retrieval, not judgment.

### Choosing when to fan out

- **Do** launch independent contracts together; each returns on its own.
- **Do not** launch a child whose result the root must have before it can write
  the next contract. Decide, write the next contract, then launch — sequential
  dependencies are the root's job, not a chain the runtime performs.
- **Do not** launch work the root will immediately duplicate while waiting. If
  the root has nothing independent to do, the task was not worth delegating.

## Write the contract

The root owns contract quality. This is where the skill succeeds or fails.

A contract must be executable by a cheap model that has **none** of the root's
context and will **not** infer missing requirements. Write it as if the reader
will do exactly what the text says and nothing more — because it will.

State the decided procedure, not options. "Consider using X or Y" is not a
contract; "refactor `src/a.ts` to use the existing `withRetry` from
`src/util/retry.ts`, replacing the inline loop at lines 40-70" is.

Include every applicable field, with concrete values rather than placeholders:

1. **Objective and context.** The user-visible outcome, why this subtask exists,
   the current behavior or evidence, and how it relates to the parent task.
   Carry forward exact user criteria, terminology, and prior decisions.
2. **Inputs and starting points.** Absolute working directory, input paths or
   identifiers, relevant files and symbols, and what to read first. Name the
   source of truth and say whether prerequisites are ready.
3. **Ownership and limits.** Files, directories, or artifacts the subagent may
   change; what it may only inspect; explicit exclusions. State relevant user and
   `AGENTS.md` constraints and allowed side effects. Include: "You are not alone
   in the codebase. Preserve unrelated changes and accommodate concurrent edits;
   do not revert others' work." State that it cannot delegate further.
4. **Decided procedure.** An ordered, task-specific sequence: where to start,
   what to inspect or change, which existing APIs or patterns to reuse, how
   dependencies connect. Record the decision the root already made instead of
   presenting options. Call out invariants, likely pitfalls, and edge cases.
   Leave only ordinary local choices open within these boundaries.
5. **Input/output contract.** Required artifact paths, formats, fields, types,
   units, stable keys, matching rules. Include a representative example, plus a
   boundary or negative example where the rule is easy to misread. Preserve
   exact literals when exact matching matters.
6. **Verification and acceptance.** Observable pass/fail criteria and the
   focused commands or inspection procedure, including working directory and
   expected behavior. Say which checks must actually run and what evidence to
   retain. A successful command or a completion message is not proof that the
   requested result is correct.
7. **Blockers and escalation.** What to do if inputs are absent, source material
   contradicts the contract, validation fails, or completion needs changes
   outside ownership. Require reporting the concrete evidence and the decision
   needed — via `caller_ping` when the child is blocked mid-run — preserving
   completed work, and pausing dependent actions instead of guessing, broadening
   scope, weakening checks, or claiming success. Independent in-scope work may
   continue.
8. **Return format.** A concise summary; changed file or artifact paths; results
   against each acceptance criterion; checks actually run with outcomes;
   remaining uncertainties and blockers. Separate verified facts from
   assumptions and mark checks that were not run. Front-load the verdict and the
   evidence, because the parent sees a truncated result.

Before sending, ask whether a subagent holding only this contract and the named
materials can tell what to do, where, what to avoid, how to verify, and when to
stop. Fill every gap first. Write down any command you already know it needs.

Follow-ups may reference the existing contract in the same child's context, but
must state the observed failure, the required correction, and the acceptance
criteria that still apply. A replacement child needs the complete current
contract and the relevant evidence — never just "continue" or "try again".

## Validate by risk, not by habit

Cheap generation makes independent checking worth more, not less. But reviewing
everything with a cheap reviewer is mostly wasted motion, and reviewing nothing
is how incorrect work ships. Grade the delivery and match the check to it.

| Risk | Signals | Check |
|---|---|---|
| **Low** | Formatting, renames, doc/index updates, mechanical sweeps, no behavior change | Root inspects the diff or artifact directly. No review child. |
| **Medium** | Contained behavior change, new code behind clear tests, additive migrations | Root runs the focused suite; delegate a review contract when the change is large enough that the root would otherwise re-read it all. |
| **High** | Security, auth, data mutation or deletion, concurrency, money/permissions, changes that are expensive or impossible to reverse | Always a review contract against the written acceptance criteria, *plus* root verification. |

Verification depth should track **blast radius**, not diff size: a one-line
permission check outranks a 500-line rename.

### The reviewer's real job

A review child runs on the cheap tier with read-only tools. Two consequences to
design around:

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

Do not treat a clean review as acceptance. The root owns the verdict.

## Protect shared work

- Inspect the worktree before assigning writes so user changes and concurrent
  ownership are visible.
- Partition contracts so parallel writes never overlap: by project, by disjoint
  paths, by distinct output artifacts, or by one managed worktree per writer.
- Never assign overlapping writes in one checkout. If overlap is unavoidable,
  serialize those contracts.
- Subagents must not commit, submit, deploy, delete, or perform other external
  or destructive actions unless the user explicitly authorized that action.
  When a worktree child commits, say so in the contract and keep the branch
  unpushed: the root owns integration.
- Do not redo a subagent's contract in the root while it is running. Continue
  orchestration, dependency analysis, or integration work that does not
  duplicate its ownership.
- Do not treat a subagent's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.
- Retained worktrees are part of the delivery: list them with `worktree_list` and
  remove them with `worktree_remove` once their content is integrated.

## Integrate and accept

Track every contract to completion. Follow up with the same child when its
context is valuable, or resume an exited child session with `subagent_resume`
rather than starting over.

Re-read each result as **claims, not conclusions**: check the diff or artifacts
against each acceptance criterion, and reconcile any report that disagrees with
what is actually on disk.

Fix small integration gaps directly in the root. For substantial rework, issue a
revised contract with a new boundary and acceptance condition rather than
patching silently.

Before reporting completion, account for every contract as accepted, superseded,
failed, or cancelled, then give one root-level conclusion.
