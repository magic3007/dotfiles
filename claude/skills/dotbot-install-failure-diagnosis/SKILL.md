---
name: dotbot-install-failure-diagnosis
description: |
  Diagnose and fix "Some tasks were not executed successfully" failures in Dotbot
  (dotfiles installer). Use when: (1) Dotbot reports install failure, (2) error shows
  "Nonexistent source" for symlink, (3) "already exists but is a regular file" symlink errors,
  (4) git clone timeouts reported in log but files actually exist. Provides step-by-step diagnosis approach.
author: Claude Code
version: 1.1.1
date: 2026-03-30
---

# Dotbot Install Failure Diagnosis

## Problem
Dotbot installation of dotfiles fails with the message "==> Some tasks were not executed successfully", but most installations complete successfully. Diagnosis is needed to find what actually failed.

## Context / Trigger Conditions
- Running `./install` with Dotbot to install dotfiles
- Final output says "Some tasks were not executed successfully"
- Log contains "Nonexistent source" for a symlink entry
- Log contains early git network errors (timeouts) that may not be actual failures
- Dotbot continues execution after errors but reports overall failure

## Solution

### Step 1: Read the full install log
Look for these specific patterns:
1. **"Nonexistent source"**: Symlink target doesn't exist in the repository
2. **"fatal:"**: Git clone or fetch failure
3. **"command not found"**: Missing package or executable
4. **"Some links were not successfully set up"**: One or more symlinks failed

### Step 2: Diagnose "Nonexistent source"
- This error means: `install.conf.yaml` has a symlink entry where the source file/directory doesn't exist in the repo
- Check: `cat install.conf.yaml | grep -n "problem-path"` to find the line
- Fix: Create the missing source directory/file in the repo, then manually create the symlink:
  ```bash
  mkdir -p /path/to/repo/problem-directory
  ln -s /path/to/repo/problem-directory ~/target-link
  ```

### Step 3: Diagnose "already exists but is a regular file or directory"
- This error means: The symlink target already exists as a real file/directory (not a symlink)
- Common causes:
  - Application (like Karabiner) already created the config file automatically
  - User manually created the file before running install
  - Previous installation left a regular file behind
- Fix: Backup then remove the existing file so Dotbot can create the symlink:
  ```bash
  # Backup existing file
  cp ~/target/path/file ~/target/path/file_bk
  # Remove existing file (use /bin/rm to bypass safe rm aliases)
  /bin/rm -f ~/target/path/file
  # Re-run install
  ./install
  ```
- If you have a safe `rm` alias that requires confirmation and `rem` is interactive, use `/bin/rm -f` to bypass.

### Step 4: Diagnose reported git failures
- Git clone timeouts don't always mean failure - check if the directory exists and is complete:
  ```bash
  ls -la ~/target-directory
  cd ~/target-directory && git status
  ```
- If directory exists and `git status` shows clean, the clone actually succeeded
- If incomplete: remove directory and retry clone:
  ```bash
  rm -rf ~/target-directory
  git clone https://github.com/username/repo.git ~/target-directory
  ```

### Step 4: Verify all critical components
After fixing symlink issues, verify key installations:
```bash
# Check oh-my-zsh plugins
ls ~/.oh-my-zsh/custom/plugins/

# Check fzf
command -v fzf && fzf --version

# Check AI CLI tools
command -v claude codex gemini opencode

# Check any other installed utilities
command -v wechat-reminder
```

### Step 5: Common fixes for this dotfiles repo
For this specific dotfiles repo:
- If `~/.claude/agents` fails: `mkdir -p /Users/minimax/dotfiles/claude/agents && ln -s /Users/minimax/dotfiles/claude/agents ~/.claude/agents`
- If oh-my-zsh plugin clone fails: retry manually in `~/.oh-my-zsh/custom/plugins/`
- If fzf install fails: `cd ~/.fzf && ./install --all`

## Verification
After fixing:
1. All symlinks reported in the log as failures should exist and point to the correct location
2. All critical components should respond to `command -v`
3. Running `./install` again should complete with "All tasks have been executed successfully"
4. Git status should be clean in cloned repositories

## Example

### Scenario
Log shows:
```
Nonexistent source ~/.claude/agents -> claude/agents
Some links were not successfully set up
fatal: unable to access 'https://github.com/zsh-users/zsh-syntax-highlighting.git/': Couldn't connect to server
==> Some tasks were not executed successfully
```

### Diagnosis
1. Check `install.conf.yaml` line 127: `~/.claude/agents: claude/agents`
2. Check repo: `ls /Users/minimax/dotfiles/claude/agents` - directory doesn't exist
3. Check zsh-syntax-highlighting: `ls -la ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting` - directory exists and is complete

### Fix
```bash
mkdir -p /Users/minimax/dotfiles/claude/agents
ln -s /Users/minimax/dotfiles/claude/agents ~/.claude/agents
```

### Verification
```
ls -la ~/.claude/agents -> points to /Users/minimax/dotfiles/claude/agents ✓
All oh-my-zsh plugins installed ✓
All AI CLIs found ✓
```

## Notes
- Dotbot is idempotent and safe to re-run - if you fix the issue, running `./install` again should work
- Network timeouts on git clones often succeed on retry, but sometimes the clone actually completes despite the timeout
- In this dotfiles repository, all network operations use `|| true` to avoid blocking the entire install - this means installation completes even if some optional components fail
- Always check the actual file system state before retrying - don't trust the error message alone

## References
- [Dotbot Documentation](https://github.com/anishathalye/dotbot)
- [This dotfiles repo CLAUDE.md](/Users/minimax/dotfiles/CLAUDE.md)
- [Install configuration](/Users/minimax/dotfiles/install.conf.yaml)
