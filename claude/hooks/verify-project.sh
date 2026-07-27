#!/bin/bash
# verify-project.sh — PostToolUse hook: lightweight syntax verification
# Runs after Edit|Write on matching file types.
set -o pipefail

for f in $CLAUDE_CHANGED_FILES; do
  [ -f "$f" ] || continue
  case "$f" in
    *.py)
      python -c "
import sys, ast
try:
    with open('$f') as fh:
        ast.parse(fh.read(), filename='$f')
except SyntaxError as e:
    print(f'⚠ PYTHON SYNTAX: $f:{e.lineno}: {e.msg}')
    sys.exit(1)
" 2>&1 || true
      ;;
    *.yaml|*.yml)
      python -c "
import sys, yaml
try:
    with open('$f') as fh:
        yaml.safe_load(fh)
except yaml.YAMLError as e:
    print(f'⚠ YAML ERROR: $f: {e}')
    sys.exit(1)
" 2>&1 || true
      ;;
    *.json)
      # Only validate JSON files that aren't huge (>1MB skip)
      size=$(stat -c%s "$f" 2>/dev/null || echo 0)
      [ "$size" -gt 1048576 ] && continue
      python -c "
import sys, json
try:
    with open('$f') as fh:
        json.load(fh)
except json.JSONDecodeError as e:
    print(f'⚠ JSON ERROR: $f: {e}')
    sys.exit(1)
" 2>&1 || true
      ;;
    Makefile|*.mk)
      dir=$(dirname "$f")
      if [ -f "$dir/Makefile" ] && grep -q '^help:' "$dir/Makefile" 2>/dev/null; then
        make -n -C "$dir" help >/dev/null 2>&1 || \
          echo "⚠ MAKEFILE: $f may have syntax issues" || true
      fi
      ;;
  esac
done
