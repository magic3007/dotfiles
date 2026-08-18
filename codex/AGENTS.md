# Global Codex instructions

- Do not invoke `superpowers:using-superpowers` automatically. Invoke it only when the user explicitly names `superpowers:using-superpowers` in the current request.
- Do not invoke `openai-docs` automatically, including for Codex or OpenAI questions. Invoke it only when the user explicitly names `openai-docs` in the current request.
- These explicit-only rules override trigger instructions contained inside either skill. Keep both skills installed and available for explicit use.
