#!/usr/bin/env bash
# Launch a coding harness with the user's secrets environment.
#
# Why this exists
# ---------------
# xMatrix starts agent runs from its systemd daemon. That daemon inherits only
# the systemd --user session environment plus the unit's own PATH — the keys in
# ~/.common_shell_setup_local.sh are never passed down. Any credential that the
# harness reads from an environment variable therefore resolves to nothing:
#
#   * omp catalog providers (deepseek, zai, kimi, openrouter, ...) send the
#     variable *name* as the API key, so the upstream answers
#     401 AuthenticationError: The API key format is incorrect.
#   * codex custom providers (config.toml `env_key = "DEEPSEEK_API_KEY"`) fail
#     the same way.
#
# Fix: make the agent's runtime this script instead of the harness binary.
#   xmatrix agent add --space <SPACE> omp --runtime ~/.local/bin/xmatrix-omp
# The harness is derived from the symlink name (`xmatrix-<harness>`), so one
# script serves every harness; the secrets stay in their single source file.
#
# Credentials that a harness reads from a file or its own vault (omp's vault,
# ~/.codex/auth.json, ~/.claude/.credentials.json, ~/.gemini/*) need none of
# this and work either way.

harness="$(basename "$0")"
harness="${harness#xmatrix-}"

secrets="${HARNESS_ENV_FILE:-$HOME/.common_shell_setup_local.sh}"
if [ -r "$secrets" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$secrets"
    set +a
fi

# The daemon PATH holds ~/.local/bin but not ~/.bun/bin, so make sure the
# harness itself is reachable even when it is not linked into ~/.local/bin.
PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export PATH

exec "$harness" "$@"
