# Explicit-only Codex Skills Implementation Plan

> **For agentic workers:** Apply the global instruction and verify its installed path directly.

**Goal:** Prevent automatic invocation of `superpowers:using-superpowers` and `openai-docs` while preserving explicit invocation.

**Architecture:** Store the override in a tracked global Codex `AGENTS.md` and link it into `~/.codex`. Do not modify managed skill or plugin caches.

**Tech Stack:** Codex instructions, Dotbot, shell assertions.

## Global Constraints

- Both skills remain installed.
- Only an explicit user mention in the current request may trigger either skill.
- Other skills retain their existing trigger behavior.

### Task 1: Add and install the global override

**Files:**
- Create: `codex/AGENTS.md`
- Modify: `install.conf.yaml`

- [ ] Add exact explicit-only rules for both skill names.
- [ ] Add the `~/.codex/AGENTS.md` Dotbot link.
- [ ] Replace the current empty global file with the configured symlink.
- [ ] Verify rule text, mapping, and symlink target.
