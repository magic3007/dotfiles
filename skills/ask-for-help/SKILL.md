---
name: ask-for-help
description: Stop repeated unproductive retries and prepare a precise Codex escalation after five materially different failed attempts at the same blocker. Use when a task remains blocked despite repeated diagnosis or recovery; do not count ordinary tool calls or repeated variants of the same action as separate attempts.
---

# Ask for Help

For each unresolved blocker, keep a short attempt ledger. An attempt counts only
when it tests a distinct hypothesis or recovery strategy and produces new
evidence. Repeating a command, changing superficial arguments, or retrying a
transient failure without new reasoning does not increment the count.

After the fifth materially different failed attempt on the same blocker:

1. Stop further retries and stop making changes for that blocker.
2. Preserve the current workspace and do not conceal or revert partial work.
3. End the current turn with a `Codex help request` containing:
   - objective and observable done condition;
   - working directory and relevant files;
   - current workspace state and edits already made;
   - the five attempts, each with hypothesis, action, evidence, and failure;
   - exact decisive error text or failing command;
   - best current diagnosis and remaining uncertainty;
   - the smallest recommended next investigation.
4. Explicitly say that five distinct attempts failed and ask the user to hand
   the request to Codex. Do not claim that Codex was contacted automatically.

If continuing would require new permission or a user choice, stop immediately
for that reason instead of manufacturing five attempts.
