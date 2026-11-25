#!/bin/bash
# UserPromptSubmit hook: make the agent evaluate every interaction for
# extractable knowledge and route it through the metaception skill.

cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧠 MANDATORY SKILL EVALUATION REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL: After completing this user request, you MUST evaluate whether
it produced extractable knowledge using the metaception skill.

EVALUATION PROTOCOL (NON-NEGOTIABLE):

1. COMPLETE the user's request first
2. EVALUATE: Ask yourself:
   - Did the user correct my approach?
   - Did this require non-obvious investigation or debugging?
   - Would this help in future similar situations, and is it absent from documentation?

3. IF YES to any question above:
   ACTIVATE: Use Skill(metaception) NOW. It turns a correction into a
   deterministic check first, and only then into validated knowledge.

4. IF NO to all questions:
   SKIP: No extraction needed

This is NOT optional. Failing to evaluate means valuable knowledge is lost.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
