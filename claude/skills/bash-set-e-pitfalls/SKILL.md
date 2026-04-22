---
name: bash-set-e-pitfalls
description: |
  Fix bash scripts that exit prematurely when using `set -e` (errexit). Use when:
  (1) Script exits early after a command "fails" but you want to continue,
  (2) Code after a failing command never executes, (3) Commands wrapped in
  functions or called via variables behave differently than expected. Covers the
  || true pattern, function return codes, and pipeline failures with set -e.
author: Claude Code
version: 1.0.0
date: 2026-03-29
---

# Bash `set -e` Pitfalls and Solutions

## Problem
Using `set -e` (errexit) in bash scripts causes the shell to exit immediately
when any command returns a non-zero exit status. This can lead to scripts
exiting early when a command "fails" - even when you want the script to
continue and handle the failure gracefully.

## Context / Trigger Conditions
- Script uses `set -e` or `set -o errexit`
- Script exits unexpectedly after a command that returns non-zero
- Code after certain commands never executes
- `./install` or similar commands that may have partial failures
- Commands like `grep` that return 1 when no matches found

## Solution

### Pattern 1: Allow command to fail with `|| true`
```bash
set -e

# This will exit the script if ./install returns non-zero
./install  # DON'T DO THIS if you want to continue

# This will continue even if ./install fails
./install || true  # CORRECT

# Alternative: check exit code explicitly
./install || INSTALL_FAILED=1
if [ -n "$INSTALL_FAILED" ]; then
    echo "Install had issues, continuing..."
fi
```

### Pattern 2: Use `if` statements (set -e is suppressed)
```bash
set -e

# This is safe - set -e is suppressed inside if conditions
if ./some-command; then
    echo "Success"
else
    echo "Failed but script continues"
fi
```

### Pattern 3: Functions and `set -e`
```bash
set -e

# Function returning non-zero will NOT exit if called in certain contexts
my_function() {
    return 1
}

# These will exit:
my_function
$(my_function)  # Command substitution

# These will NOT exit:
my_function || true
if my_function; then ...; fi
my_function; local status=$?  # Assignment absorbs the exit
```

### Pattern 4: Disable errexit temporarily
```bash
set -e

# Temporarily disable
set +e
./risky-command
EXIT_CODE=$?
set -e

# Now handle the result
if [ $EXIT_CODE -ne 0 ]; then
    echo "Command failed with $EXIT_CODE"
fi
```

## Verification
After applying the fix:
1. Run the script with a command that returns non-zero
2. Verify the script continues to execute subsequent commands
3. Check that the exit code is properly handled if needed

## Example

**Problematic bootstrap.sh:**
```bash
#!/bin/bash
set -e

./install  # If this returns non-zero, script exits here!
claude "$PROMPT"  # Never runs if ./install failed
```

**Fixed bootstrap.sh:**
```bash
#!/bin/bash
set -e

./install || true  # Continue even if install has issues
echo "Install completed (with possible errors)"
claude "$PROMPT"  # Now this runs
```

## Notes

- `set -e` behavior varies between bash versions and has many edge cases
- Commands in `&&` and `||` chains don't trigger errexit (except the last)
- Commands in pipelines only trigger errexit on the last command (unless `set -o pipefail`)
- In CI/CD scripts, sometimes it's better to be explicit with `|| true` than rely on errexit

## References
- [Bash Manual: The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [BashFAQ 105: Why doesn't set -e (or -o errexit, or trap ERR) do what I expected?](http://mywiki.wooledge.org/BashFAQ/105)
