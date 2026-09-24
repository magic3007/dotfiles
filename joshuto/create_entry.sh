#!/bin/sh
# Yazi-style create: a trailing slash requests a directory. Ctrl-C/empty input cancels.
set -eu
printf 'Create file or directory (end with / for directory): '
IFS= read -r entry || exit 0
[ -n "$entry" ] || exit 0
case $entry in /*) ;; *) entry=./$entry ;; esac
case $entry in
    */) mkdir -p "$entry" ;;
    *)
        # Do not overwrite existing files, symlinks, or their modification times.
        if [ -e "$entry" ] || [ -L "$entry" ]; then
            printf 'Already exists: %s\n' "$entry" >&2
            exit 1
        fi
        mkdir -p "$(dirname "$entry")"
        (set -C; : > "$entry")
        ;;
esac
