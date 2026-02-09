# Repository Guidelines

## Project Structure & Module Organization
- Root-level directories map to tools or platforms (e.g., `bash/`, `git/`, `neovim/`, `tmux.conf`, `karabiner/`, `vscode/`).
- Installation logic lives in `install` and `install.conf.yaml` (Dotbot config + shell steps).
- Submodules and third-party helpers live under `dotbot/` and `dotbot-git/`.
- Cross-cutting shell config is in `common_shell_setup.sh`, with tool-specific configs alongside their directories.

## Build, Test, and Development Commands
- `./install`: Runs Dotbot to symlink configs and perform setup steps (idempotent). This may invoke package managers (`apt`, `brew`) and use `sudo`.
- `git submodule update --init --recursive`: Ensures `dotbot/` and other submodules are present (also run by `./install`).

## Coding Style & Naming Conventions
- Prefer small, focused edits to the relevant tool directory (e.g., `git/gitconfig`, `neovim/`, `bash/`).
- Shell scripts use `#!/usr/bin/env bash` with `set -e` where appropriate (see `install`).
- Config files generally follow the tool’s native formatting; do not reformat unless necessary.
- Naming: keep filenames aligned with the target dotfile (e.g., `tmux.conf`, `npmrc`, `pip.conf`).

## Testing Guidelines
- There is no automated test suite. Validate changes by running `./install` in a safe environment and verifying the resulting dotfiles or tool behavior.

## Commit & Pull Request Guidelines
- Commit messages mostly follow a Conventional Commits style like `feat(gemini): ...` or `chore(install): ...`, though plain messages also exist.
- Use a clear scope when touching a specific tool or config directory (e.g., `chore(vscode): ...`).
- PRs should include a short summary, key files touched, and any manual verification notes (e.g., “ran `./install`”). Screenshots are only needed for editor/GUI config changes.

## Security & Configuration Tips
- Review `install.conf.yaml` shell steps before running; it installs packages and downloads tools.
- Local overrides can be stored in `~/.gitconfig_local` and `~/.zsh_local` (not tracked here).
