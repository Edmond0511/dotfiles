#!/usr/bin/env bash

input=$(cat)

# Extract all fields in one jq call, one per line (read keeps empty lines)
{
  read -r model
  read -r cwd
  read -r used_pct
  read -r vim_mode
  read -r session_id
  read -r duration_ms
  read -r lines_added
  read -r lines_removed
} < <(echo "$input" | jq -r '
  (.model.display_name // "Unknown Model"),
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // ""),
  (.vim.mode // ""),
  (.session_id // ""),
  (.cost.total_duration_ms // ""),
  (.cost.total_lines_added // ""),
  (.cost.total_lines_removed // "")')

# Session name isn't in the input JSON; Claude Code keeps it in the per-pid
# registry that /list-agents reads, so match it by session id.
session_name=""
if [ -n "$session_id" ]; then
  session_file=$(grep -l "$session_id" "$HOME"/.claude/sessions/*.json 2>/dev/null | head -1)
  if [ -n "$session_file" ]; then
    session_name=$(jq -r '.name // empty' "$session_file" 2>/dev/null)
  fi
fi

# Shorten the path: replace $HOME with ~
short_cwd="$cwd"
[[ "$cwd" == "$HOME"* ]] && short_cwd="~${cwd#"$HOME"}"

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

# Session name (first, so each pane is identifiable against /list-agents)
if [ -n "$session_name" ]; then
  output="${output}$(printf "${BOLD}${GREEN}%s${RESET}" "$session_name")"
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
fi

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
  used_int=$(printf "%.0f" "$used_pct")
  if [ "$used_int" -ge 80 ] 2>/dev/null; then
    ctx_color="$RED"
  elif [ "$used_int" -ge 50 ] 2>/dev/null; then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
  output="${output}$(printf "${ctx_color}ctx %s%%${RESET}" "$used_int")"
fi

# Lines changed this session (only once something changed)
if [ -n "$lines_added" ] && [ $((lines_added + lines_removed)) -gt 0 ]; then
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
  output="${output}$(printf "${GREEN}+%s${RESET} ${RED}-%s${RESET}" "$lines_added" "$lines_removed")"
fi

# Session duration
if [ -n "$duration_ms" ]; then
  mins=$((${duration_ms%.*} / 60000))
  if [ "$mins" -ge 60 ]; then
    dur=$(printf "%dh%02dm" $((mins / 60)) $((mins % 60)))
  else
    dur="${mins}m"
  fi
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  |  ")"
  output="${output}$(printf "${WHITE}%s${RESET}" "⏱ $dur")"
fi

# Vim mode (blue, only when active)
if [ -n "$vim_mode" ]; then
  output="${output}$(printf "${DIM}${WHITE}%s${RESET}" "  ")"
  output="${output}$(printf "${BOLD}${BLUE}%s${RESET}" "[$vim_mode]")"
fi

printf "%b" "$output"
