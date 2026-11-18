# Antigravity CLI (`agy`)

Delivery: **merge**, never link. See `docs/REPO_GUIDE.md` §2 for why.

Binary: `~/.local/bin/agy`, installed by
`curl -fsSL https://antigravity.google/cli/install.sh | bash` from phase 2 of
`install.conf.yaml`. The per-account shell wrappers in `common_shell_setup.sh`
are `agyh` (`~/.gemini`, `gemini-4-hydrogen-medium`) and `agyc` (`~/.gemini-2`,
`gemini-4-carbon-medium`), using `agy`'s hidden global flag `--gemini_dir`
(which must precede any subcommand).

## Settings are merged, not linked

The settings file is `<gemini_dir>/antigravity-cli/settings.json` (by default
`~/.gemini/antigravity-cli/settings.json`) — **not**
`<gemini_dir>/config/config.json`, which only holds plugins. `agy` rewrites it in
place on every `/config` change, model switch, workspace-trust grant and
mid-session permission grant.

`scripts/antigravity-settings-sync.py` re-applies the tracked keys across every
existing `~/.gemini*/antigravity-cli/settings.json` on install and on every
15-minute tick, keeping live-only keys (`model`,
`trustedWorkspaces`) verbatim. It dumps with sorted keys, because `agy` itself
writes them alphabetically — otherwise every save would churn the file.

Tracked keys are the permission policy:

| Key | Accepted values (verified) | Pinned here |
|---|---|---|
| `toolPermission` | `strict`, `proceed-in-sandbox`, `request-review` (default), `always-proceed` | `always-proceed` |
| `artifactReviewPolicy` | `always-proceed` | `always-proceed` |

So plain `agy` starts with full permissions; the `--dangerously-skip-permissions`
flag the `agyh`/`agyc` wrappers pass is redundant with it.

`permissions.defaultMode: "bypassPermissions"` is accepted by the validator but
has no effect — the binary contains no such literal. Do not rely on it.

## Probing accepted values

`--settings '{...}'` overrides a setting for one session and validates in two
stages: an unknown key gives `unknown setting "X"`, a known key with a bad value
gives `unrecognized value`. That two-level error is the fastest way to enumerate
what a build accepts.

## Skills

`agy` reads global skills **only** from `~/.gemini/config/skills/<name>/SKILL.md`,
one level deep, and it **skips symlinked entries listed in a `skills.json`**
manifest — but it does follow a symlink that sits directly in that directory.
So `scripts/sync-skills.py` builds it as one more generated view: a real
directory of per-skill symlinks, holding the shared skills plus the external ones
in `~/.agents/skills` — the same set omp sees. It syncs every existing
`~/.gemini*/config/skills` and does not create the directory when
`<gemini_dir>/config` is absent.

Project skills need no step: `agy` discovers `<workspace>/.agents/skills`
natively.

## Model availability

Model ids carry the effort suffix (`gemini-4-hydrogen-medium`), so switching
effort means switching id; `agy models` lists the variants.

Wrappers `agyh` (`~/.gemini`, `gemini-4-hydrogen-medium`) and `agyc`
(`~/.gemini-2`, `gemini-4-carbon-medium`) in `common_shell_setup.sh` cover the
two accounts and models in use. Passing `--model <other>` after `agyh`/`agyc`
overrides the default for that invocation.

## Installer pollution

The installer appends `# Added by Antigravity CLI installer` plus a PATH line to
`~/.bashrc`, `~/.zshrc`, `~/.profile` and the fish config. The first three are
symlinks into this repository, so the installer edits tracked files. Delete those
lines after every install — `~/.local/bin` is already on PATH.

`.repo-std/checks/no_installer_pollution.py` fails the gate when they survive.

## Antigravity the IDE

Unrelated to the CLI despite the name: `antigravity_config/` holds the
VS Code-family editor's `settings.json` and `keybindings.json`, linked into
`~/Library/Application Support/Antigravity/User/` on macOS only.
