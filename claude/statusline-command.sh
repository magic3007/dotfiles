#!/usr/bin/env bash
# Status line for Claude Code
# Derived from the user's Starship prompt (gruvbox theme, ~/.config/starship.toml)
# This script processes JSON input from stdin and outputs a status line.
# Colors use the gruvbox palette: orange=#d65d0e, yellow=#d79921, aqua=#689d6a,
# blue=#458588, bg3=#665c54, bg1=#3c3836, fg0=#fbf1c7, green=#98971a

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
repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')
pr_number=$(echo "$input" | jq -r '.pr.number // empty')
pr_review=$(echo "$input" | jq -r '.pr.review_state // empty')
time=$(date +%R)

# Gruvbox color codes (ANSI 256 to match gruvbox palette)
# Claude Code renders colors as dimmed, so we use bright variants
orange='\033[38;5;214m'      # gruvbox orange #d65d0e
yellow='\033[38;5;220m'      # gruvbox yellow #d79921
aqua='\033[38;5;108m'        # gruvbox aqua #689d6a
blue='\033[38;5;68m'         # gruvbox blue #458588
gray='\033[38;5;242m'        # gruvbox bg3 #665c54
darkgray='\033[38;5;239m'    # gruvbox bg1 #3c3836
green='\033[38;5;142m'       # gruvbox green #98971a
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

# Build the output in Starship-inspired segments

# (1) OS icon + username (orange, matching Starship $os + $username)
printf "${orange}${reset} " 2>/dev/null  # Linux icon (falls back to nothing)
printf "${orange}%s${reset}" "${user}@${host}"

# (2) Directory (yellow, matching Starship $directory)
dir_display="${dir/#$HOME/~}"
printf " ${yellow}%s${reset}" "$dir_display"

# (3) Git branch + status (aqua, matching Starship $git_branch + $git_status)
if [ -n "$dir" ] && [ -d "$dir/.git" ]; then
  branch=$(git --git-dir="$dir/.git" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -n "$branch" ]; then
    status=$(git --git-dir="$dir/.git" --no-optional-locks status --porcelain --ignore-submodules=dirty 2>/dev/null || true)
    dirty=""
    [ -n "$status" ] && dirty="*"
    printf " ${aqua} %s%s${reset}" "$branch" "$dirty"
  fi
fi

# (4) Repo owner/name (dimmed, when available from workspace)
if [ -n "$repo" ]; then
  printf " ${dim}${gray}(%s)${reset}" "$repo"
fi

# (5) PR number (when available)
if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
  review_info=""
  if [ -n "$pr_review" ] && [ "$pr_review" != "null" ]; then
    review_info="[${pr_review}]"
  fi
  printf " ${blue}PR#%s%s${reset}" "$pr_number" "${review_info}"
fi

# (6) Context window (dimmed, red when low)
if [ -n "$context_remaining" ] && [ "$context_remaining" != "null" ]; then
  pct=$(printf "%.0f" "$context_remaining")
  if [ "$pct" -lt 20 ]; then
    printf " ${orange}ctx:%d%%${reset}" "$pct"
  else
    printf " ${dim}ctx:%d%%${reset}" "$pct"
  fi
fi

# (7) Claude.ai rate limits (dimmed)
rate_out=""
if [ -n "$rate_5h" ] && [ "$rate_5h" != "null" ]; then
  rate_out="5h:$(printf '%.0f' "$rate_5h")%"
fi
if [ -n "$rate_7d" ] && [ "$rate_7d" != "null" ]; then
  [ -n "$rate_out" ] && rate_out="${rate_out} "
  rate_out="${rate_out}7d:$(printf '%.0f' "$rate_7d")%"
fi
if [ -n "$rate_out" ]; then
  printf " ${dim}${gray}%s${reset}" "$rate_out"
fi

# (8) Vim mode indicator (bold yellow for NORMAL mode)
if [ -n "$vim_mode" ] && [ "$vim_mode" != "null" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    printf " ${bold}${yellow}NORMAL${reset}"
  fi
fi

# (9) Session name (cyan)
if [ -n "$session_name" ] && [ "$session_name" != "null" ]; then
  printf " ${blue}\"%s\"${reset}" "$session_name"
fi

# (10) Time (gray, matching Starship $time)
printf " ${gray}%s${reset}" "$time"

# (11) Model (dimmed, at the end)
if [ -n "$model" ] && [ "$model" != "null" ]; then
  printf " ${dim}%s${reset}" "$model"
fi