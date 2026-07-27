#!/usr/bin/env bash
# Status line for Claude Code
# Derived from shell PS1: \u@\h:\w (green user@host, blue directory)
# This script processes JSON input from stdin and outputs a status line.
# Colors: using dimmed ANSI colors (Claude Code renders them dimmed)

set -euo pipefail

# Read JSON input
input=$(cat)

# Extract fields
user=$(whoami)
host=$(hostname -s)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
context_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Color codes (dimmed as Claude Code renders them dimmed)
green='\033[32m'
blue='\033[34m'
yellow='\033[33m'
cyan='\033[36m'
magenta='\033[35m'
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

# Build the output
out=""

# user@host in green (matching PS1's \u@\h)
out="${out}${green}${user}@${host}${reset}"

# directory in blue (matching PS1's \w)
# Shorten home directory to ~
dir_display="${dir/#$HOME/~}"
out="${out}:${blue}${dir_display}${reset}"

# Git branch info (optional, skip locks)
if [ -n "$dir" ] && [ -d "$dir/.git" ]; then
  branch=$(git --git-dir="$dir/.git" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -n "$branch" ]; then
    out="${out} ${magenta}(${branch})${reset}"
  fi
fi

# Context window
if [ -n "$context_remaining" ] && [ "$context_remaining" != "null" ]; then
  pct=$(printf "%.0f" "$context_remaining")
  if [ "$pct" -lt 20 ]; then
    out="${out} ${yellow}ctx:${pct}%${reset}"
  else
    out="${out} ${dim}ctx:${pct}%${reset}"
  fi
fi

# Claude.ai rate limits
rate_out=""
if [ -n "$rate_5h" ] && [ "$rate_5h" != "null" ]; then
  rate_out="5h:$(printf '%.0f' "$rate_5h")%"
fi
if [ -n "$rate_7d" ] && [ "$rate_7d" != "null" ]; then
  [ -n "$rate_out" ] && rate_out="${rate_out} "
  rate_out="${rate_out}7d:$(printf '%.0f' "$rate_7d")%"
fi
if [ -n "$rate_out" ]; then
  out="${out} ${dim}${rate_out}${reset}"
fi

# Vim mode indicator
if [ -n "$vim_mode" ] && [ "$vim_mode" != "null" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    out="${out} ${bold}${yellow}NORMAL${reset}"
  fi
fi

# Session name
if [ -n "$session_name" ] && [ "$session_name" != "null" ]; then
  out="${out} ${cyan}\"${session_name}\"${reset}"
fi

# Model
if [ -n "$model" ] && [ "$model" != "null" ]; then
  out="${out} ${dim}${model}${reset}"
fi

# Print the result (no trailing $ or > as per instructions)
printf "%b" "$out"