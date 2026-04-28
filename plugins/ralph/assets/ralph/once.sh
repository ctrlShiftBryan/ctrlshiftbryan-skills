#!/usr/bin/env bash
# Run one Ralph iteration. Reads PROMPT.md. No looping, no branch management, no PR.
# Usage: ralph/once.sh [--engine claude|codex] [--prompt PATH] [--log PATH]
# Used standalone for HITL ("kick the tires") and as the inner of ralph/afk.sh.

set -uo pipefail

engine="claude"
prompt="PROMPT.md"
log=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) engine="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --log)    log="$2";    shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$engine" in claude|codex) ;; *) echo "unknown engine: $engine" >&2; exit 2 ;; esac
[[ -f "$prompt" ]] || { echo "missing prompt: $prompt" >&2; exit 1; }

run() {
  case "$engine" in
    claude) claude -p "$(cat "$prompt")" --dangerously-skip-permissions ;;
    codex)  codex exec --dangerously-bypass-approvals-and-sandbox "$(cat "$prompt")" ;;
  esac
}

if [[ -n "$log" ]]; then
  run 2>&1 | tee "$log"
else
  run
fi
