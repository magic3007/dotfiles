#!/usr/bin/env bash
# The one entry point. CI and humans both run this and nothing else.
#
#   .repo-std/gate.sh            run every check against the repository
#   .repo-std/gate.sh --prove    run every check against its violating fixture
#
# --prove is the negative control: a guard that has never failed is a guard
# nobody tested. It passes only when every check *fails* on its fixture.
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
            printf 'PASS  %s\n' "$name"
        else
            printf 'FAIL  %s\n%s\n' "$name" "$out"
            fail=1
        fi
        continue
    fi

    fixture="$FIXTURES/$name"
    if [[ -x "$fixture/prove.sh" ]]; then
        if "$fixture/prove.sh" >/dev/null 2>&1; then
            printf 'PROVE %s (fixture rejected, via prove.sh)\n' "$name"
        else
            printf 'BROKEN %s: prove.sh did not observe a failure\n' "$name"
            fail=1
        fi
    elif [[ -d "$fixture" ]]; then
        if python3 "$check" --root "$fixture" >/dev/null 2>&1; then
            printf 'BROKEN %s: passes on its violating fixture — it guards nothing\n' "$name"
            fail=1
        else
            printf 'PROVE %s (fixture rejected)\n' "$name"
        fi
    else
        printf 'BROKEN %s: no fixture at %s\n' "$name" "${fixture#$ROOT/}"
        fail=1
    fi
done

exit "$fail"
