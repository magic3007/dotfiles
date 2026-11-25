#!/usr/bin/env bash
# The one entry point. CI and humans both run this and nothing else.
#
#   .repo-std/gate.sh            run every check against the repository
#   .repo-std/gate.sh --prove    run every check against its violating fixture
#
# --prove is the negative control: a guard that has never failed is a guard
# nobody tested. It passes only when every check *reports a violation* (a
# `FAIL  ` line) on its fixture; a crash or a bare non-zero exit proves nothing.
# A fixture that needs real git state is an executable fixtures/<name>/prove.sh
# that builds it and runs the check, under the same contract.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKS="$ROOT/.repo-std/checks"
FIXTURES="$CHECKS/fixtures"
cd "$ROOT"

mode="run"
[[ "${1:-}" == "--prove" ]] && mode="prove"

fail=0
for check in "$CHECKS"/*.py; do
    name="$(basename "$check" .py)"
    [[ "$name" == _* ]] && continue

    if [[ "$mode" == "run" ]]; then
        if out="$(python3 "$check" --root "$ROOT" 2>&1)"; then
            if [[ "$out" == SKIP* ]]; then
                printf 'SKIP  %s: %s\n' "$name" "${out#SKIP  }"
            else
                printf 'PASS  %s\n' "$name"
            fi
        else
            printf 'FAIL  %s\n%s\n' "$name" "$out"
            fail=1
        fi
        continue
    fi

    fixture="$FIXTURES/$name"
    if [[ -x "$fixture/prove.sh" ]]; then
        out="$("$fixture/prove.sh" 2>&1)"
    elif [[ -d "$fixture" ]]; then
        out="$(python3 "$check" --root "$fixture" 2>&1)"
    else
        printf 'BROKEN %s: no fixture at %s\n' "$name" "${fixture#$ROOT/}"
        fail=1
        continue
    fi
    if grep -q '^FAIL  ' <<<"$out"; then
        printf 'PROVE %s (fixture rejected)\n' "$name"
    else
        printf 'BROKEN %s: no violation reported on its fixture\n%s\n' "$name" "$out"
        fail=1
    fi
done

exit "$fail"
