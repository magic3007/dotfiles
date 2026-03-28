#!/usr/bin/env bash
# yolo-generic - Lightweight sandbox with bubblewrap for CLI tools
# Adapted from https://github.com/wongsingfo/nano-llm-relay
#
# Usage: yolo-generic <command> [args...]
# Runs the command in a lightweight bubblewrap sandbox

set -euo pipefail

fail() {
    echo "$*" >&2
    exit 1
}

has_arg() {
    local needle=$1
    shift

    local arg
    for arg in "$@"; do
        if [[ "$arg" == "$needle" || "$arg" == "$needle="* ]]; then
            return 0
        fi
    done

    return 1
}

has_arg_pair() {
    local needle=$1
    local value=$2
    shift 2

    local arg
    while [[ $# -gt 0 ]]; do
        arg=$1
        shift

        if [[ "$arg" == "$needle" ]]; then
            if [[ "${1-}" == "$value" ]]; then
                return 0
            fi
            continue
        fi

        if [[ "$arg" == "$needle=$value" ]]; then
            return 0
        fi
    done

    return 1
}

append_env_if_set() {
    local -n env_args_ref=$1
    local name=$2

    if [[ "${!name+x}" == "x" ]]; then
        env_args_ref+=(--setenv "$name" "${!name}")
    fi
}

append_bind_if_exists() {
    local -n bind_args_ref=$1
    local -n bind_seen_ref=$2
    local mode=$3
    local path=$4

    [[ -e "$path" ]] || return 0
    if [[ -z "${bind_seen_ref[$path]+x}" ]]; then
        bind_seen_ref[$path]=1
        bind_args_ref+=("$mode" "$path" "$path")
    fi
}

append_dir_if_missing() {
    local -n mount_args_ref=$1
    local -n dir_seen_ref=$2
    local path=$3

    if [[ -z "${dir_seen_ref[$path]+x}" ]]; then
        dir_seen_ref[$path]=1
        mount_args_ref+=(--dir "$path")
    fi
}

path_is_under() {
    local path=$1
    local prefix=$2

    [[ "$path" == "$prefix" || "$path" == "$prefix/"* ]]
}

abspath() {
    local path=$1
    local dir

    dir=$(cd -- "$(dirname -- "$path")" && pwd -P)
    printf '%s/%s\n' "$dir" "$(basename -- "$path")"
}

is_system_bound_path() {
    local path=$1

    path_is_under "$path" "/usr" ||
        path_is_under "$path" "/bin" ||
        path_is_under "$path" "/lib" ||
        path_is_under "$path" "/lib64" ||
        path_is_under "$path" "/etc"
}

resolve_command_path() {
    local command_name=$1
    local resolved

    if [[ "$command_name" == */* ]]; then
        resolved=$(abspath "$command_name")
    else
        resolved=$(type -P -- "$command_name" || true)
    fi

    [[ -n "$resolved" ]] || fail "command not found: $command_name"
    [[ -f "$resolved" ]] || fail "not a file: $resolved"
    [[ -x "$resolved" ]] || fail "not executable: $resolved"
    printf '%s\n' "$resolved"
}

mount_command_paths() {
    local -n mount_args_ref=$1
    local -n ro_seen_ref=$2
    local original_path=$3
    local real_path=$4
    local workdir=$5
    local home_dir=$6
    local candidate
    local prefix
    local matched_prefix

    for candidate in "$original_path" "$real_path"; do
        matched_prefix=false
        for prefix in "$home_dir/.npm" "$home_dir/.cargo" "$home_dir/.local"; do
            if [[ -e "$prefix" ]] && path_is_under "$candidate" "$prefix"; then
                append_bind_if_exists "$1" "$2" --ro-bind "$prefix"
                matched_prefix=true
                break
            fi
        done

        if [[ "$matched_prefix" == true ]]; then
            continue
        fi

        if ! is_system_bound_path "$candidate" && ! path_is_under "$candidate" "$workdir"; then
            append_bind_if_exists "$1" "$2" --ro-bind "$(dirname -- "$candidate")"
        fi
    done
}

mount_tool_state() {
    local -n mount_args_ref=$1
    local -n rw_seen_ref=$2
    local tool_name=$3
    local home_dir=$4
    local xdg_config_home=$5
    local xdg_cache_home=$6

    append_bind_if_exists "$1" "$2" --bind "$xdg_cache_home"

    case "$tool_name" in
        claude)
            append_bind_if_exists "$1" "$2" --bind "$home_dir/.claude"
            append_bind_if_exists "$1" "$2" --bind "$home_dir/.claude.json"
            ;;
        codex)
            append_bind_if_exists "$1" "$2" --bind "$home_dir/.codex"
            append_bind_if_exists "$1" "$2" --bind "$xdg_config_home/codex"
            ;;
    esac
}

mount_resolver_runtime() {
    local -n mount_args_ref=$1
    local -n ro_seen_ref=$2
    local -n dir_seen_ref=$3
    local resolv_source
    local runtime_dir
    local current_dir

    [[ -e /etc/resolv.conf ]] || return 0
    resolv_source=$(readlink -f -- /etc/resolv.conf)
    [[ -n "$resolv_source" ]] || return 0
    path_is_under "$resolv_source" "/run" || return 0

    runtime_dir=$(dirname -- "$resolv_source")
    current_dir="/run"
    append_dir_if_missing "$1" "$3" "$current_dir"

    local relative_dir=${resolv_source#/run/}
    local component
    IFS=/ read -r -a runtime_parts <<< "$relative_dir"
    for component in "${runtime_parts[@]}"; do
        current_dir="$current_dir/$component"
        append_dir_if_missing "$1" "$3" "$current_dir"
    done

    append_bind_if_exists "$1" "$2" --ro-bind "$runtime_dir"
}

main() {
    local bwrap_path
    bwrap_path=$(type -P -- bwrap || true)
    [[ -n "$bwrap_path" ]] || fail "bwrap is not installed or not on PATH"
    [[ $# -gt 0 ]] || fail "usage: yolo-generic.sh <command> [args...]"
    : "${HOME:?HOME must be set}"

    local workdir original_command original_path real_path tool_name
    local xdg_config_home xdg_cache_home
    workdir=$(pwd -P)
    original_command=$1
    shift
    original_path=$(resolve_command_path "$original_command")
    real_path=$(readlink -f -- "$original_path")
    tool_name=$(basename -- "$original_path")
    xdg_config_home=${XDG_CONFIG_HOME:-$HOME/.config}
    xdg_cache_home=${XDG_CACHE_HOME:-$HOME/.cache}

    local -a bwrap_args=(
        --clearenv
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --unshare-all
        --share-net
        --die-with-parent
    )
    local -A ro_seen=()
    local -A rw_seen=()
    local -A dir_seen=()

    append_bind_if_exists bwrap_args ro_seen --ro-bind /usr
    append_bind_if_exists bwrap_args ro_seen --ro-bind /bin
    append_bind_if_exists bwrap_args ro_seen --ro-bind /lib
    append_bind_if_exists bwrap_args ro_seen --ro-bind /lib64
    append_bind_if_exists bwrap_args ro_seen --ro-bind /etc
    mount_resolver_runtime bwrap_args ro_seen dir_seen

    mount_command_paths bwrap_args ro_seen "$original_path" "$real_path" "$workdir" "$HOME"

    append_bind_if_exists bwrap_args rw_seen --bind "$workdir"
    mount_tool_state bwrap_args rw_seen "$tool_name" "$HOME" "$xdg_config_home" "$xdg_cache_home"

    bwrap_args+=(
        --chdir "$workdir"
        --setenv HOME "$HOME"
        --setenv PATH "${PATH:-/usr/bin:/bin}"
        --setenv PWD "$workdir"
    )

    local env_name
    for env_name in \
        TERM COLORTERM LANG LC_ALL NO_COLOR \
        XDG_CONFIG_HOME XDG_CACHE_HOME \
        HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY \
        http_proxy https_proxy all_proxy no_proxy \
        ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_MODEL \
        OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_PROJECT_ID \
        CODEX_HOME CLAUDE_CODE_SIMPLE; do
        append_env_if_set bwrap_args "$env_name"
    done

    local -a command_args=("$original_path")
    case "$tool_name" in
        codex)
            if ! has_arg "--dangerously-bypass-approvals-and-sandbox" "$@"; then
                command_args+=(--dangerously-bypass-approvals-and-sandbox)
            fi
            ;;
        claude)
            if ! has_arg "--dangerously-skip-permissions" "$@" \
                && ! has_arg_pair "--permission-mode" "bypassPermissions" "$@"; then
                command_args+=(--dangerously-skip-permissions)
            fi
            ;;
    esac
    command_args+=("$@")

    set -x
    exec "$bwrap_path" "${bwrap_args[@]}" "${command_args[@]}"
}

main "$@"
