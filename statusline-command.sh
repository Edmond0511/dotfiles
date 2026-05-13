#!/usr/bin/env bash
# Claude Code Status Line for NoteCal dev environment

input=$(cat)

# Extract fields
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')

# Effort level: prefer input JSON, fall back to ~/.claude/settings.json
effort=$(echo "$input" | jq -r '.effortLevel // .effort_level // empty')
if [ -z "$effort" ] && [ -f "$HOME/.claude/settings.json" ]; then
  effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

# Shorten the path: replace $HOME with ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (fast, skip optional locks)
git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    git_branch="$branch"
  fi
fi

# ANSI colors
RESET="\033[0m"
BOLD="\033[1m"

CYAN="\033[36m"
MAGENTA="\033[35m"
YELLOW="\033[33m"
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
WHITE="\033[37m"
DIM="\033[2m"

# Build output
output=""

# Model (most prominent — magenta + bold)
output="${output}$(printf "${BOLD}${MAGENTA}%s${RESET}" " $model")"

# Separator
output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"

# Directory (cyan)
output="${output}$(printf "${CYAN}%s${RESET}" "$short_cwd")"

# Git branch (yellow, only if present)
if [ -n "$git_branch" ]; then
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  ")"
  output="${output}$(printf "${YELLOW}%s${RESET}" " $git_branch")"
fi

# Context usage (green/yellow/red based on amount used)
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "$used_int" -ge 80 ] 2>/dev/null; then
    ctx_color="$RED"
  elif [ "$used_int" -ge 50 ] 2>/dev/null; then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
  output="${output}$(printf "${ctx_color}ctx %s%%%s${RESET}" "$used_pct" "")"
fi

# Effort level (color-coded: low=dim, medium=cyan, high=yellow, xhigh=red)
if [ -n "$effort" ]; then
  case "$effort" in
    low)    eff_color="$DIM$WHITE" ; eff_label="low" ;;
    medium) eff_color="$CYAN"      ; eff_label="med" ;;
    high)   eff_color="$YELLOW"    ; eff_label="high" ;;
    xhigh)  eff_color="$RED"       ; eff_label="xhigh" ;;
    *)      eff_color="$WHITE"     ; eff_label="$effort" ;;
  esac
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
  output="${output}$(printf "${eff_color}%s${RESET}" "⚡$eff_label")"
fi

# Vim mode (blue, only when active)
if [ -n "$vim_mode" ]; then
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  ")"
  output="${output}$(printf "${BOLD}${BLUE}%s${RESET}" "[$vim_mode]")"
fi

printf "%b" "$output"
