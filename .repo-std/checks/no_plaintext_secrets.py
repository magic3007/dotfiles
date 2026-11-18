#!/usr/bin/env python3
"""No plaintext credentials in tracked files.

This repository is public. Every agent harness here takes a *reference* instead
of a literal: models.yml and gateways-login.json take an environment variable
name, mcode takes '${MAFIA_API_KEY}', VS Code takes ${input:chat.lm.secret.*}.
The real values live in the untracked ~/.common_shell_setup_local.sh.

The check looks for credential *shapes* (provider key prefixes, long opaque
tokens next to a key-ish name), not for the word "key": a name alone proves
nothing and a prefix is hard to write by accident.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

# Literal provider prefixes. Each is a published format, so a match is a real key.
PREFIXES = re.compile(
    r"\b("
    r"sk-[A-Za-z0-9]{20,}"            # OpenAI / DeepSeek / Moonshot
    r"|sk-ant-[A-Za-z0-9_-]{20,}"     # Anthropic
    r"|ghp_[A-Za-z0-9]{30,}"          # GitHub personal token
    r"|github_pat_[A-Za-z0-9_]{30,}"
    r"|AIza[A-Za-z0-9_-]{30,}"        # Google API
    r"|xoxb-[A-Za-z0-9-]{20,}"        # Slack bot
    r"|tskey-auth-[A-Za-z0-9-]{20,}"  # Tailscale auth key
    r"|AKIA[A-Z0-9]{16}"              # AWS access key id
    r")"
)

# A key-ish assignment whose value is a long opaque literal. The value must look
# like a credential — base64/hex alphabet, mixing letters and digits — not like
# code (`process.env[...]`) or prose, both of which also run past 24 characters.
ASSIGNMENT = re.compile(
    r"""(?ix)
    \b(api[_-]?key|apikey|secret|token|password|webhook[_-]?url)
    \s*[:=]\s*
    ["']?
    (?P<value>(?=[A-Za-z0-9_+/=-]*[A-Za-z])(?=[A-Za-z0-9_+/=-]*[0-9])[A-Za-z0-9_+/=-]{24,})
    """
)

# Values that are references, not secrets.
REFERENCE = re.compile(
    r"""(?x)
    ^(
      \$\{?[A-Za-z_][A-Za-z0-9_]*\}?      # $VAR / ${VAR}
      | ![^\s]+                            # !command
      | [A-Z][A-Z0-9_]{2,}$                # a bare env-var NAME
      | \$\{input:.*\}                     # VS Code secret storage
      | <.*>                               # placeholder
      | \.\.\..*                           # elision in prose
      | https?://[^\s]*(example|placeholder|YOUR|xxx|\.\.\.)[^\s]*
    )
    """
)

SKIP_DIRS = {"skills", "archive", "dotbot", "dotbot-git", "oh-my-zsh", "vim", ".repo-std"}
SKIP_SUFFIXES = {".png", ".jpg", ".plist", ".lock", ".xsd"}


def tracked_files(root: Path) -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, capture_output=True, text=True, check=False
    )
    names = [name for name in out.stdout.split("\0") if name] if out.returncode == 0 else []
    if not names:
        # Not a checkout, or a subtree with nothing tracked (a fixture): scan the
        # tree directly rather than silently scanning nothing.
        return [p for p in root.rglob("*") if p.is_file()]
    return [root / name for name in names]


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []
    scanned = 0

    for path in tracked_files(root):
        rel = path.relative_to(root)
        if rel.parts and rel.parts[0] in SKIP_DIRS:
            continue
        if path.suffix in SKIP_SUFFIXES or not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        scanned += 1
        for lineno, line in enumerate(text.splitlines(), 1):
            hit = PREFIXES.search(line)
            if hit:
                violations.append(f"{rel}:{lineno}: literal credential ({hit.group(1)[:8]}…)")
                continue
            match = ASSIGNMENT.search(line)
            if match and not REFERENCE.match(match.group("value")):
                violations.append(
                    f"{rel}:{lineno}: credential-shaped literal; use an env-var name, "
                    f"${{VAR}} or !command instead"
                )

    return report(violations, f"{scanned} tracked files carry no literal credential")


if __name__ == "__main__":
    raise SystemExit(main())
