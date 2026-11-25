# Assignment brief

The fields every delegation carries, in the order the worker reads them. Include
only the applicable ones, but never leave one as a placeholder.

1. **Objective and context.** The user-visible outcome, why this subtask is
   needed, the current behavior or evidence, and its relation to the parent task.
   Carry forward exact user criteria, terminology, and prior decisions.
2. **Inputs and starting points.** Absolute working directory, input paths or
   identifiers, relevant files and symbols, and what to read first. Name the
   source of truth and say whether prerequisites are ready.
3. **Ownership and limits.** Files, directories, or artifacts the worker may
   change; what it may only inspect; explicit exclusions. State the user and
   `AGENTS.md` constraints, the allowed validation and side effects, and whether
   the worker may delegate further. Include: "You are not alone in the codebase.
   Preserve unrelated changes and accommodate concurrent edits; do not revert
   others' work."
4. **Decided procedure.** An ordered, task-specific sequence: where to start,
   what to inspect or change, which existing APIs or patterns to reuse, how
   dependencies connect. Record the decision the root already made instead of
   presenting options. Call out invariants, likely pitfalls, and edge cases;
   leave only ordinary local choices open inside these boundaries.
5. **Input/output contract.** Required artifact paths, formats, fields, types,
   units, stable keys, and matching rules. Include a representative example plus
   a boundary or negative example where the rule is easy to misread. Preserve
   exact literals when exact matching matters.
6. **Verification and acceptance.** Observable pass/fail criteria and the focused
   commands or inspection procedure, including the working directory and the
   expected behavior. Say which checks must run and what evidence to retain. A
   successful command or a completion message is not proof that the requested
   result is correct.
7. **Blockers and escalation.** What to do if inputs are absent, source material
   contradicts the brief, validation fails, or completion needs changes outside
   ownership. Require the concrete evidence and the decision needed to reach the
   assigning agent, preservation of completed work, and a pause on dependent
   actions instead of guessing, broadening scope, weakening checks, or claiming
   success. Independent in-scope work may continue.
8. **Return format.** A concise summary, changed file or artifact paths, results
   against each acceptance criterion, checks actually run with outcomes, and
   remaining uncertainties or blockers. Separate verified facts from assumptions
   and mark checks that were not run.

## Before sending

Ask whether a worker holding only this brief and the named materials can tell
what to do, where, how to verify, and when to stop. Fill every gap first, and
write down any command the worker will need that already is known.

## Follow-ups and replacements

A follow-up may reference an existing contract in the same worker's context, but
must state the observed failure, the required correction, and the acceptance
criteria that still apply. A replacement worker needs the complete current brief
and the relevant evidence — never only "continue" or "try again".
