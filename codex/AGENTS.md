# Global Codex instructions

- Invoke `toil-offloading` automatically by default whenever its applicability conditions are met; the user does not need to name it explicitly. Keep small, non-decomposable tasks local as required by the skill.
- Do not invoke `superpowers:using-superpowers` automatically. Invoke it only when the user explicitly names `superpowers:using-superpowers` in the current request.
- These explicit-only rules override trigger instructions contained inside either skill. Keep both skills installed and available for explicit use.
