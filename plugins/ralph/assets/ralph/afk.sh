#!/usr/bin/env bash
# Loop ralph/once.sh until <promise>COMPLETE</promise>, --max, or Ctrl-C.
# On COMPLETE: push the branch and open a draft PR. Otherwise: notify only.
# Usage: ralph/afk.sh [--engine claude|codex] [--max N] [--branch NAME] [--base NAME] [--sleep N]

set -uo pipefail

engine="claude"
max=0
sleep_s=2
branch="ralph/work"
base="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) engine="$2"; shift 2 ;;
    --max)    max="$2";    shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --base)   base="$2";   shift 2 ;;
    --sleep)  sleep_s="$2"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$engine" in claude|codex) ;; *) echo "unknown engine: $engine" >&2; exit 2 ;; esac
mkdir -p ralph/.state

i=0
exit_reason="ctrl-c"
finish() {
  if [[ "$exit_reason" == "complete" ]]; then
    git push -u origin "$branch" 2>&1 || true
    pr_url=$(gh pr create --draft --base "$base" --head "$branch" \
      --title "Ralph: $(basename "$PWD") build" \
      --body "Auto-generated draft PR from \`ralph/afk.sh\`. See \`progress.md\` for the per-issue commit log and \`fix_plan.md\` for the issues addressed." \
      2>&1) && echo "draft PR: $pr_url"
    bash ralph/notify.sh "Ralph done" "COMPLETE — draft PR opened ($i iters)"
  else
    bash ralph/notify.sh "Ralph paused" "engine=$engine iters=$i reason=$exit_reason"
  fi
  exit 0
}
trap 'exit_reason="signal"; finish' INT TERM

git rev-parse --verify "$branch" >/dev/null 2>&1 || git checkout -b "$branch" "$base"
git checkout "$branch"

while :; do
  i=$((i + 1))
  [[ $max -gt 0 && $i -gt $max ]] && { exit_reason="max ($max)"; finish; }

  log="ralph/.state/loop-$(printf '%03d' "$i").log"
  echo "── ralph loop $i ($engine) → $log"

  ralph/once.sh --engine "$engine" --log "$log"

  if grep -q "<promise>COMPLETE</promise>" "$log"; then
    exit_reason="complete"; finish
  fi

  sleep "$sleep_s"
done
