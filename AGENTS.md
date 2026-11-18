# AGENTS.md

Index only. The rules, the process and the reasoning live in
`docs/REPO_GUIDE.md`; this file exists so an agent starting cold knows where to
look and what will reject its change.

## Before you finish, run the gate

```bash
bash .repo-std/gate.sh
```

It is the whole contract. It fails on the mistakes this repository has actually
made: a link added to only one dotbot config, a self-rewriting config that was
symlinked, a literal credential, a SKILL.md without a description, an untracked
skill that is not gitignored, a doc naming a path that no longer exists, a
comment in `omp/config.yml`, an installer line left in a tracked rc file, a
script that does not parse.

Every one of those is a correction someone made once, recorded in
`.repo-std/corrections.yml` next to the check that now enforces it. Adding a
rule means adding a check — `docs/REPO_GUIDE.md` §5 has the four steps. Do not
add a rule to this file.

## Where things are

| Question | Answer |
|---|---|
| how a config reaches the machine | `docs/REPO_GUIDE.md` §2 — link, merge, or seed |
| which file owns a fact | `docs/REPO_GUIDE.md` §3 |
| where to start for a given change | `docs/REPO_GUIDE.md` §4 |
| how to verify | `docs/REPO_GUIDE.md` §6 |
| what is out of scope | `docs/REPO_GUIDE.md` §7 — vendored, archived, runtime state |
| harness detail | `omp/README.md`, `codex/README.md`, `mcode/README.md`, `antigravity/README.md`, `herdr/README.md`, `herdr-app/README.md`, `neovim/README.md` |
| what this repo configures, for a visitor | `README.md` |

`CLAUDE.md` is a symlink to this file.

## Two things that surprise everyone

- **There is no dry-run.** The pinned Dotbot rejects `-n` and `--dry-run`.
  Preview with `./install --only link`, which is idempotent.
- **`./install` and `sync.sh` read different files.** `install.conf.yaml` and
  `sync.conf.yaml` must both carry every link; the gate enforces it.
