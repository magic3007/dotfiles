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
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
context_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# pi-powerline-footer replica (preset "default", separator "powerline-thin")
# Colors below mirror pi-powerline-footer's theme.ts DEFAULT_COLORS resolved
# against the gruvbox-dark theme; model/path are hardcoded pink/teal in pi
# itself (colors.ts THEME), independent of the active theme.
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

model_c=$(rgb 215 135 175)    # #d787af pink/mauve — pi hardcodes this, not gruvbox
path_c=$(rgb 0 175 175)       # #00afaf teal/cyan  — pi hardcodes this, not gruvbox
success_c=$(rgb 184 187 38)   # #b8bb26 gruvbox-dark bright green  (git clean / staged)
warning_c=$(rgb 250 189 47)   # #fabd2f gruvbox-dark bright yellow (git dirty / unstaged / ctx warn)
error_c=$(rgb 251 73 52)      # #fb4934 gruvbox-dark bright red    (ctx error)
muted_c=$(rgb 146 131 116)    # #928374 gruvbox-dark gray          (untracked / ctx dim)
text_c=$(rgb 235 219 178)     # #ebdbb2 gruvbox-dark fg             (cost)
sep_c=$(printf '\033[38;5;244m') # ANSI256 244 — pi's fixed separator color (colors.ts THEME.sep)
reset=$(printf '\033[0m')

# Nerd Font icons (matching pi-powerline-footer's icons.ts NERD_ICONS)
icon_model=$''    # nf-md-chip
icon_folder=$''   # nf-fa-folder_open
icon_branch=$''   # nf-fa-code_fork
icon_context=$''  # nf-fa-database
icon_cost=$''     # nf-fa-dollar
sep=$''           # nf powerline-thin separator (chars.powerlineThinLeft)

# ─────────────────────────────────────────────────────────────────────────
# pi-powerline-footer "default" preset segment order:
#   model, thinking, shell_mode, path, git, context_pct, cache_read, cost
# thinking / shell_mode / cache_read have no Claude Code statusline JSON
# equivalent (extended-thinking level, bash-mode toggle, prompt-cache-read
# tokens aren't exposed here) — skipped.
# ─────────────────────────────────────────────────────────────────────────

parts=()

# (1) model — pi modelSegment: icon+name, both colored (hardcoded pink #d787af)
if [ -n "$model" ] && [ "$model" != "null" ]; then
  parts+=("${model_c}${icon_model} ${model}${reset}")
fi

# (2) path — pi pathSegment, mode "basename" (default preset): icon+name, both colored (hardcoded teal #00afaf)
if [ -n "$dir" ]; then
  base=$(basename "$dir")
  parts+=("${path_c}${icon_folder} ${base}${reset}")
fi

# (3) git — pi gitSegment: branch (icon+name) colored by clean/dirty, then per-indicator colors
if [ -n "$dir" ] && [ -d "$dir/.git" ]; then
  branch=$(git --git-dir="$dir/.git" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -n "$branch" ]; then
    status=$(git --git-dir="$dir/.git" --no-optional-locks status --porcelain --ignore-submodules=dirty 2>/dev/null || true)
    staged=0; unstaged=0; untracked=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      case "$line" in
        \?\?*) untracked=$((untracked + 1)) ;;
        *)
          [ "${line:0:1}" != " " ] && staged=$((staged + 1))
          [ "${line:1:1}" != " " ] && unstaged=$((unstaged + 1))
          ;;
      esac
    done <<< "$status"

    if [ "$staged" -gt 0 ] || [ "$unstaged" -gt 0 ] || [ "$untracked" -gt 0 ]; then
      branch_c="$warning_c"
    else
      branch_c="$success_c"
    fi
    git_seg="${branch_c}${icon_branch} ${branch}${reset}"
    indicators=""
    [ "$unstaged" -gt 0 ] && indicators="${indicators}${warning_c}*${unstaged}${reset} "
    [ "$staged" -gt 0 ] && indicators="${indicators}${success_c}+${staged}${reset} "
    [ "$untracked" -gt 0 ] && indicators="${indicators}${muted_c}?${untracked}${reset} "
    [ -n "$indicators" ] && git_seg="${git_seg} ${indicators% }"
    parts+=("$git_seg")
  fi
fi

# (4) context_pct — pi contextPctSegment: icon uncolored, pct text colored by threshold
#     (>90% error, >70% warn, else dim). pi shows "{used}/{window} (pct%)"; Claude's
#     statusline JSON only exposes percentages here (no raw token/window counts),
#     so this is an approximation with percentage only.
if [ -n "$context_used" ] && [ "$context_used" != "null" ]; then
  pct=$(printf '%.1f' "$context_used")
  pct_i=$(printf '%.0f' "$context_used")
  if [ "$pct_i" -gt 90 ]; then
    ctx_c="$error_c"
  elif [ "$pct_i" -gt 70 ]; then
    ctx_c="$warning_c"
  else
    ctx_c="$muted_c"
  fi
  parts+=("${icon_context} ${ctx_c}${pct}%${reset}")
fi

# (5) cost — pi costSegment: "$X.XX", color "text", NO icon (pi's costSegment
#     doesn't call withIcon despite icons.cost existing). usingSubscription has
#     no Claude Code equivalent, so only the reported-cost branch applies.
if [ -n "$cost_usd" ] && [ "$cost_usd" != "null" ] && awk -v c="$cost_usd" 'BEGIN{exit !(c>0)}' 2>/dev/null; then
  cost_fmt=$(printf '%.2f' "$cost_usd")
  parts+=("${text_c}\$${cost_fmt}${reset}")
fi

# ─────────────────────────────────────────────────────────────────────────
# Join with pi's powerline-thin separator, replicating buildContentFromParts
# in pi-powerline-footer/segments.ts:
#   " " + parts.join(` ${sepAnsi}${sep}${reset} `) + reset + " "
# ─────────────────────────────────────────────────────────────────────────
if [ "${#parts[@]}" -gt 0 ]; then
  out="${parts[0]}"
  for ((i = 1; i < ${#parts[@]}; i++)); do
    out="${out} ${sep_c}${sep}${reset} ${parts[$i]}"
  done
  printf ' %s%s ' "$out" "$reset"
fi
