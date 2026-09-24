#!/bin/sh
# Shared opener policy with yazi/yazi.toml. Paths are passed as arguments, never eval'd.
set -eu
operation=$1
shift
# Joshuto supplies bare filenames; normalize leading dashes before calling applications.
for path do
    case $path in /*) ;; *) path=$PWD/$path ;; esac
    shift
    set -- "$@" "$path"
done
case "$operation" in
    edit)
        # Match Yazi: allow EDITOR to contain command-line options, without eval.
        set -f
        exec ${EDITOR:-vim} "$@"
        ;;
    open)
        if [ "$(uname -s)" = Darwin ]; then
            exec open "$@"
        fi
        for path do xdg-open "$path"; done
        ;;
    reveal)
        if [ "$(uname -s)" = Darwin ]; then
            exec open -R "$@"
        fi
        for path do xdg-open "$(dirname "$path")"; done
        ;;
    exif)
        exiftool "$@" || true
        printf '\nPress enter to exit'
        IFS= read -r reply || true
        ;;
    *) printf 'Unknown opener: %s\n' "$operation" >&2; exit 2 ;;
esac
