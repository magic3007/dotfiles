#!/usr/bin/env bash
# =============================================================================
# Tailscale tailnet join
# =============================================================================
# Idempotent: while the node is Running this script does nothing, so ./install
# can call it on every run. Set TAILSCALE_RECONFIGURE=1 to re-apply flags.
#
# Environment (put in ~/.common_shell_setup_local.sh, never commit):
#   TAILSCALE_AUTHKEY        auth key for unattended login. Accepts a literal
#                            tskey-auth-... or file:/path/to/key. Only needed
#                            until the node is logged in; without it the script
#                            prints the manual `tailscale up` command and exits 0.
#   TAILSCALE_HOSTNAME       hostname shown in the admin console / MagicDNS.
#   TAILSCALE_SSH            1 (default) or 0: run a Tailscale SSH server.
#   TAILSCALE_ACCEPT_ROUTES  1 (default) or 0: accept routes advertised by
#                            subnet routers (Linux defaults to off).
#   TAILSCALE_ACCEPT_DNS     true|false. Unset keeps the daemon default (accept).
#   TAILSCALE_UP_FLAGS       extra `tailscale up` flags, whitespace separated:
#                            "--advertise-exit-node --advertise-routes=192.168.1.0/24"
#                            "--exit-node=devbox --exit-node-allow-lan-access"
#                            `tailscale up` flags are not persisted by the CLI;
#                            when reconfiguring, spell out every flag you need.
#   TAILSCALE_RECONFIGURE    1: run `tailscale up` even when already Running.
#
# Usage: scripts/tailscale-setup.sh [--dry-run]
# =============================================================================
set -u

usage() {
    printf 'usage: %s [--dry-run]\n' "${0##*/}" >&2
    exit 2
}

DRY_RUN=0
case "${1-}" in
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    *) usage ;;
esac

info() { printf '[tailscale] %s\n' "$*"; }
warn() { printf '[tailscale] WARNING: %s\n' "$*" >&2; }

# ./install does not source the interactive shell config, so pick up the auth
# key from the same machine-local file that common_shell_setup.sh sources.
# Only when the key is absent: an explicit environment must win.
if [ -z "${TAILSCALE_AUTHKEY:-}" ] && [ -f "$HOME/.common_shell_setup_local.sh" ]; then
    set +u
    # shellcheck disable=SC1090,SC1091
    . "$HOME/.common_shell_setup_local.sh" >/dev/null 2>&1 || true
    set -u
fi

# The macOS standalone/App Store app ships the CLI inside the bundle. Use it
# when the "Install CLI" step has not created /usr/local/bin/tailscale.
find_cli() {
    if command -v tailscale >/dev/null 2>&1; then
        command -v tailscale
        return 0
    fi
    local app
    for app in "/Applications/Tailscale.app/Contents/MacOS/Tailscale" \
               "$HOME/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
        if [ -x "$app" ]; then
            printf '%s\n' "$app"
            return 0
        fi
    done
    return 1
}

CLI=$(find_cli) || {
    warn "tailscale CLI not found; run ./install or install-scripts/{mac,linux}/install-packages.sh"
    exit 0
}

# The app bundle binary opens a GUI window unless this is set. It is harmless
# for the standalone CLI and for Linux.
export TAILSCALE_BE_CLI=1

SUDO=()
run_ts() {
    if [ "${#SUDO[@]}" -gt 0 ]; then
        "${SUDO[@]}" "$CLI" "$@"
    else
        "$CLI" "$@"
    fi
}

# Establish whether the daemon is reachable as this user; on Linux (and the
# Homebrew open-source daemon) it requires root. Never prompt for a password
# from ./install: fall back to printing the manual command.
status_json=$(run_ts status --json 2>/dev/null) || status_json=""
if [ -z "$status_json" ] && [ "$(id -u)" -ne 0 ]; then
    if sudo -n true 2>/dev/null; then
        SUDO=(sudo -n)
        status_json=$(run_ts status --json 2>/dev/null) || status_json=""
    fi
fi

if [ -z "$status_json" ]; then
    warn "cannot reach tailscaled as $(id -un)"
    if [ "$(id -u)" -ne 0 ]; then
        info "start the daemon, then re-run:"
        case "$CLI" in
            *Tailscale.app/Contents/MacOS/Tailscale)
                info "  macOS app: open -a Tailscale   (approve the system extension on first launch)"
                ;;
            *)
                [ "$(uname)" = "Darwin" ] &&
                    info "  macOS Homebrew daemon: sudo brew services start tailscale"
                [ "$(uname)" = "Linux" ] &&
                    info "  Linux: sudo systemctl enable --now tailscaled"
                ;;
        esac
        info "  $CLI up --ssh --accept-routes"
    fi
    exit 0
fi

state=$(printf '%s\n' "$status_json" |
    sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1)

if [ "$state" = "Running" ] && [ "${TAILSCALE_RECONFIGURE:-0}" != "1" ]; then
    ip=$(run_ts ip -4 2>/dev/null | head -n 1 || true)
    info "already connected${ip:+ ($ip)}; set TAILSCALE_RECONFIGURE=1 to re-apply flags"
    exit 0
fi

UP_ARGS=()
[ "${TAILSCALE_SSH:-1}" != "0" ] && UP_ARGS+=(--ssh)
[ "${TAILSCALE_ACCEPT_ROUTES:-1}" != "0" ] && UP_ARGS+=(--accept-routes)
[ -n "${TAILSCALE_ACCEPT_DNS:-}" ] && UP_ARGS+=("--accept-dns=${TAILSCALE_ACCEPT_DNS}")
[ -n "${TAILSCALE_HOSTNAME:-}" ] && UP_ARGS+=("--hostname=${TAILSCALE_HOSTNAME}")
if [ -n "${TAILSCALE_UP_FLAGS:-}" ]; then
    # Deliberate word splitting: TAILSCALE_UP_FLAGS is a flag list.
    # shellcheck disable=SC2206
    UP_ARGS+=(${TAILSCALE_UP_FLAGS})
fi

if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    UP_ARGS+=("--auth-key=${TAILSCALE_AUTHKEY}")
elif [ "$state" != "Running" ]; then
    warn "node is $state and TAILSCALE_AUTHKEY is not set"
    # Never print a key; this branch only runs when there is none.
    info "log in manually:"
    info "  ${SUDO[*]+${SUDO[*]} }$CLI up ${UP_ARGS[*]}"
    info "or set TAILSCALE_AUTHKEY (tskey-auth-... or file:/path) in ~/.common_shell_setup_local.sh"
    exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
    display="${SUDO[*]+${SUDO[*]} }$CLI up ${UP_ARGS[*]}"
    [ -n "${TAILSCALE_AUTHKEY:-}" ] && display=${display//"$TAILSCALE_AUTHKEY"/<redacted>}
    info "would run: $display"
    exit 0
fi

info "joining the tailnet..."
if run_ts up "${UP_ARGS[@]}"; then
    ip=$(run_ts ip -4 2>/dev/null | head -n 1 || true)
    info "connected${ip:+ ($ip)}"
else
    warn "tailscale up failed; node stays in state $state"
    exit 1
fi
