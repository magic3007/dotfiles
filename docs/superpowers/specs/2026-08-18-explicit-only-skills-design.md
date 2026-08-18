# Explicit-only Codex skills

Codex must keep `superpowers:using-superpowers` and `openai-docs` installed and available, but must not invoke either skill automatically. They may be invoked only when the user explicitly names the corresponding skill in the current request.

The rule belongs in the global `~/.codex/AGENTS.md` instructions rather than plugin caches, so plugin and system-skill updates cannot overwrite it. Dotbot will link the tracked `codex/AGENTS.md` into that location.

Verification checks the tracked rule text, the Dotbot mapping, and the live symlink target.
