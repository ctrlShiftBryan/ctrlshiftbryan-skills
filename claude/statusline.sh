#!/bin/bash
input=$(cat)

# Optional: capture metrics to sidecar file (async, non-blocking); skipped if hook not installed
[ -f ~/.claude/hooks/capture-session-metrics.js ] && echo "$input" | node ~/.claude/hooks/capture-session-metrics.js &

MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd' | xargs printf '%.2f')
IN_TOKENS=$(echo "$input" | jq '.context_window.current_usage.input_tokens // 0')
OUT_TOKENS=$(echo "$input" | jq '.context_window.current_usage.output_tokens // 0')
SESSION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms')
API_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
CURRENT=$(echo "$input" | jq '.context_window.current_usage.input_tokens + .context_window.current_usage.cache_creation_input_tokens + .context_window.current_usage.cache_read_input_tokens // 0')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // empty')

PERCENT=$((CURRENT * 100 / CONTEXT_SIZE))
SESSION_TIME=$(printf '%dm%02ds' $((SESSION_MS / 60000)) $(((SESSION_MS % 60000) / 1000)))
API_TIME=$(printf '%ds' $((API_MS / 1000)))
IN_K=$(printf '%.1fK' $(echo "scale=1; $IN_TOKENS / 1000" | bc))
OUT_K=$(printf '%.1fK' $(echo "scale=1; $OUT_TOKENS / 1000" | bc))

# Use main worktree path for project name (handles worktrees correctly)
MAIN_WORKTREE=$(git -C "$PROJECT_DIR" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
if [ -n "$MAIN_WORKTREE" ]; then
  DIR_NAME=$(basename "$MAIN_WORKTREE")
else
  DIR_NAME=$(basename "$PROJECT_DIR" 2>/dev/null || echo "?")
fi

# Get git branch from project dir (empty if not a repo)
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Colors
R="\033[0m"       # Reset
DIM="\033[2m"     # Dim
BOLD="\033[1m"
CYAN="\033[36m"
MAGENTA="\033[35m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"

# Context color based on usage
if [ "$PERCENT" -lt 50 ]; then
  CTX_COLOR=$GREEN
elif [ "$PERCENT" -lt 75 ]; then
  CTX_COLOR=$YELLOW
else
  CTX_COLOR=$RED
fi

# Build dir:branch or just dir
if [ -n "$BRANCH" ]; then
  LOCATION="${CYAN}${DIR_NAME}${DIM}:${R}${MAGENTA}${BRANCH}${R}"
else
  LOCATION="${CYAN}${DIR_NAME}${R}"
fi

echo -e "${LOCATION} ${DIM}│${R} ${BOLD}${MODEL}${R} ${DIM}│${R} ${CTX_COLOR}${PERCENT}%${R} ${DIM}│${R} ${YELLOW}\$${COST}${R} ${DIM}│${R} ${DIM}in:${R}${IN_K} ${DIM}out:${R}${OUT_K} ${DIM}│${R} ${DIM}${SESSION_TIME} api:${API_TIME}${R}"
