# fish config — ARCHIVED (frozen, no longer maintained)

Archived 2026-09-17. Moved here from `fish/` at the repo root.

## Status

**Frozen, not maintained.** The config still *works* — it is deliberately kept
usable rather than deleted — but no new features, fixes, or dependency updates
should go into this directory.

## Why it still works

`install.conf.yaml` still creates the symlink, now pointing at this location:

```
~/.config/fish -> <repo>/archive/fish
```

This is intentional. An existing fish login keeps its full config (aliases,
fzf bindings, nvm, AI-tool wrappers). Removing the symlink would silently strip
all of that for anyone who happens to run fish.

## What was removed when archiving

The Fisher plugin bootstrap and `fisher update` steps were deleted from
`install.conf.yaml` (previously the "Fish shell plugins (Fisher)" shell block).
Rationale: Fisher reaches out to the network on every `./install`, installs
nothing useful now that the config is frozen, and its pinned plugin list
(`fish_plugins`) had already been deliberately deleted from the repo in commit
`f3ea88f` ("Plugins are installed via Fisher at setup time") — so the step was
re-downloading state the repo no longer pins.

`fish` itself is still installed as a package by
`install-scripts/{linux,mac}/install-packages.sh`, and
`install-scripts/change-default-shell.sh` still offers it as a shell choice.
Neither is fish *config* maintenance, so both were left alone.

## Rules for this directory

- Do **not** add new fish config, aliases, functions, or completions.
- Do **not** re-add fish-related symlink or Fisher install steps to
  `install.conf.yaml`.
- Do **not** delete the symlink without the user's explicit decision — that is
  the difference between "frozen" and "removed".
- If you genuinely need to revive fish, treat it as a fresh decision: un-archive
  with `git mv archive/fish fish`, restore the symlink target, and re-evaluate
  whether Fisher is worth reinstating.

## Contents

- `config.fish` — tool initialization (starship, zoxide, conda, venv)
- `conf.d/` — modular config (env vars, PATH, aliases, fzf, ssh)
- `functions/` — lazy-loaded functions (one per file)
- `completions/` — fisher / nvm / fzf completions
- `themes/` — empty

Local-only files, still gitignored in their new location:
`conf.d/local.fish`, `fish_variables`.

`fish_plugins` is present locally but **not tracked** (removed in `f3ea88f`);
it is regenerable Fisher state.
