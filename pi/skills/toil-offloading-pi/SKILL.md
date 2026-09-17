---
name: toil-offloading-pi
description: "Orchestrate decomposable workloads with pi subagents (afang-subagent extension): the strong-but-slow root agent clarifies goals, cuts the work into contract-bearing subtasks, fans them out to cheap-and-fast subagents, grades delivery risk, runs an independent review where it pays, and accepts the result. Use when the user asks for toil offloading, broad delegation, multi-project fan-out, or substantial work that can be split; do not use for a small task that is faster to complete directly."
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

Use the `subagent` tool exposed by the `afang-subagent` extension. Do not launch
agent CLIs (claude, codex, gemini, ...) as shell subprocesses.

## The two-tier model

| Tier | Model | Owns |
|---|---|---|
| **Root** | the session's strong/slow model | Goal clarification, decomposition, architecture and design calls, contract authorship, integration, risk grading, acceptance |
| **Subagents** | cheap/fast (set by `PI_SUBAGENT_PROVIDER` + `PI_SUBAGENT_MODEL`) | Executing contracts: recon, implementation, refactoring, data extraction, artifact generation, test writing, verification runs, review |

Delegation is the default for decomposable work because the marginal subtask
costs a cheap model's time, not the root's. The root should be spending its
context on the plan and the acceptance decision, not on typing out the changes.

### Where the tier is declared

The split is one session-wide setting, not a per-agent choice:

```sh
export PI_SUBAGENT_PROVIDER="dspro"
export PI_SUBAGENT_MODEL="deepseek-flash[1m]"
```

It lives in `~/.common_shell_setup_local.sh` so every pi session inherits it,
including the plain `pi` aliases. Resolution order in the `afang-subagent`
extension: these env vars → agent frontmatter `model:` → current session model.
Because the env vars win, do not pin models in agent frontmatter — that would be
a second source of truth that silently loses. To change the subagent tier, change
the env vars.

### Why cheap subagents are safe here

A weak model is dangerous when it must *decide* and safe when it must *execute*.
So the contract, not the model, carries the reasoning: confirm the approach in
the root, write it down concretely, and let the subagent do the volume. This is
why contract quality is the single most important thing this skill governs. A
vague contract handed to a cheap model produces a confident guess, which is
worse than no delegation.

## pi runtime constraints

Hard limits — design the batch around them:

- **Modes**: single (`{agent, task}`), parallel (`{tasks: [...]}`), chain
  (`{chain: [...]}`, sequential with `{previous}`), background
  (`{agent, task, background: true, topic?}`, returns `task-N` immediately).
- **Fan-out width**: `PI_SUBAGENT_MAX_PARALLEL_TASKS` (default 64) tasks per
  parallel call, `PI_SUBAGENT_MAX_CONCURRENCY` (default 16) running at once,
  `PI_SUBAGENT_BG_MAX_TASKS` (default 16) background tasks. These are the
  extension's current defaults; read the live tool schema if a call is rejected.
- **No nested delegation.** The root session is depth 0; a spawned subagent is
  depth 1 and does **not** register the `subagent` tool. A subagent cannot
  delegate further — never write a contract that assumes it will.
- **No per-task model override.** The subagent model is a session-wide setting,
  declared once by the `PI_SUBAGENT_PROVIDER` / `PI_SUBAGENT_MODEL` environment
  variables (set in `~/.common_shell_setup_local.sh`), which override every
  subagent for the session. Agent frontmatter `model:` is the fallback when
  those are unset; a subagent with neither inherits the current session model.
  There is no "use a smarter model just for this one task" — choose the agent
  type and the contract quality instead.
- **Available agents** (builtin, shipped with the extension):

  | Agent | Tools | Use for |
  |---|---|---|
  | `scout` | read, grep, find, ls, bash | Fast recon returning compressed context |
  | `planner` | read, grep, find, ls | Turning settled context into an ordered plan |
  | `worker` | full | Implementation, refactoring, artifacts — has write access |
  | `reviewer` | read, grep, find, ls, bash (read-only) | Independent review against acceptance criteria |

  User agents in `~/.pi/agent/agents/` override same-name builtins. Run
  `subagent {}` to list what the runtime actually exposes.
- **Monitoring**: `/subagent` (alias `/sa`) opens a panel to watch each child's
  trajectory and kill individuals without aborting the batch. The
  `subagent_tasks` tool (`list` / `status` / `result` / `cancel`) covers both
  foreground live and background tasks.
- Background results land in `<task cwd>/.pi/subagent-results/<timestamp>-<task-id>-<slug>.md`
  (falls back to `~/.pi/agent/subagent-results/` when not writable).

## Start with real work

Do not create availability, model-identity, provider-routing, or capability
probe assignments. Treat the advertised agent types as the session contract and
send the first useful contracts directly. If a subagent cannot start or finish,
record its actual outcome and continue other safe, useful work. Reassign only
when the scope and acceptance condition remain explicit; never replace a
subagent with a shell subprocess.

## Partition

Cut by **what can stand alone**, not by what is easy.

| Subagent | Work |
|---|---|
| `scout` | Locating code, tracing dependencies, gathering context the root has not seen |
| `planner` | Converting settled context and requirements into an ordered plan |
| `worker` | Implementation, refactoring, migration, batch edits, artifacts, test writing, running the focused suite |
| `reviewer` | Independent read-only review of a delivered change against its acceptance criteria |

Keep in the root:

- Requirement clarification and any genuine ambiguity in the goal.
- Architecture, interface, and design trade-off calls — the decisions a contract
  is supposed to encode.
- Risk grading and the accept/rework verdict.
- Conflict resolution, destructive or externally mutating actions, final
  integration.

Do not delegate a decision and call it "investigation" — if the root does not
know the answer, decide it first, then delegate execution of that decision. The
one legitimate exception is *context gathering*: a `scout` may return facts the
root then reasons over. That is retrieval, not judgment.

### Choosing between parallel, chain, and background

- **Parallel** for independent subtasks. This is the default; prefer it. With a
  64/16 budget, a large mechanical sweep should be partitioned wide.
- **Chain** only for a real dependency, using `{previous}` when a later step
  consumes an earlier result the root has not yet seen. Do not chain work the
  root can integrate itself — routing results through the root is usually better,
  because the root is the one that must understand them.
- **Background** when the root has independent useful work to do meanwhile.
  Do not background a task and then idle waiting for it.

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
   needed, preserving completed work, and pausing dependent actions instead of
   guessing, broadening scope, weakening checks, or claiming success.
   Independent in-scope work may continue.
8. **Return format.** A concise summary; changed file or artifact paths; results
   against each acceptance criterion; checks actually run with outcomes;
   remaining uncertainties and blockers. Separate verified facts from
   assumptions and mark checks that were not run.

Before sending, ask whether a subagent holding only this contract and the named
materials can tell what to do, where, what to avoid, how to verify, and when to
stop. Fill every gap first. Write down any command you already know it needs.

Follow-ups may reference the existing contract in the same subagent's context,
but must state the observed failure, the required correction, and the acceptance
criteria that still apply. A replacement subagent needs the complete current
contract and the relevant evidence — never just "continue" or "try again".

## Validate by risk, not by habit

Cheap generation makes independent checking worth more, not less. But reviewing
everything with a cheap reviewer is mostly wasted motion, and reviewing nothing
is how incorrect work ships. Grade the delivery and match the check to it.

| Risk | Signals | Check |
|---|---|---|
| **Low** | Formatting, renames, doc/index updates, mechanical sweeps, no behavior change | Root inspects the diff or artifact directly. No reviewer. |
| **Medium** | Contained behavior change, new code behind clear tests, additive migrations | Root runs the focused suite; delegate `reviewer` when the change is large enough that the root would otherwise re-read it all. |
| **High** | Security, auth, data mutation or deletion, concurrency, money/permissions, changes that are expensive or impossible to reverse | Always `reviewer` against the written acceptance criteria, *plus* root verification. |

Verification depth should track **blast radius**, not diff size: a one-line
permission check outranks a 500-line rename.

### The reviewer's real job

`reviewer` is read-only (`read, grep, find, ls, bash`) and runs on the cheap
model. Two consequences to design around:

- **It is a second pass over the acceptance criteria, not an oracle.** Give it
  the criteria and the changed paths, and ask for specific findings with file
  and line numbers. It is good at catching "the contract said X and the code
  does Y", missing edge cases, and obvious defects.
- **A cheap reviewer cannot out-reason the root.** When a high-risk change needs
  judgment the cheap model may not be trusted with, the root does the deep
  review itself; the `reviewer` pass is an additional sweep for concrete
  discrepancies, not a substitute for the root's verdict.

Do not treat a clean review as acceptance. The root owns the verdict.

## Protect shared work

- Inspect the worktree before assigning writes so user changes and concurrent
  ownership are visible.
- Partition contracts so parallel writes never overlap: by project, by disjoint
  paths, or by distinct output artifacts.
- Never assign overlapping writes in one checkout. If overlap is unavoidable,
  serialize those contracts, or use isolated worktrees when already authorized.
- Subagents must not commit, submit, deploy, delete, or perform other external
  or destructive actions unless the user explicitly authorized that action.
- Do not redo a subagent's contract in the root while it is running. Continue
  orchestration, dependency analysis, or integration work that does not
  duplicate its ownership.
- Do not treat a subagent's success message as acceptance evidence. Inspect the
  materialized changes or outputs and run proportionate verification.

## Integrate and accept

Track every contract to completion. Follow up with the same subagent when its
context is valuable. Re-read each result as **claims, not conclusions**: check
the diff or artifacts against each acceptance criterion, and reconcile any
report that disagrees with what is actually on disk.

Fix small integration gaps directly in the root. For substantial rework, issue a
revised contract with a new boundary and acceptance condition rather than
patching silently.

Before reporting completion, account for every contract as accepted, superseded,
failed, or cancelled, then give one root-level conclusion.
