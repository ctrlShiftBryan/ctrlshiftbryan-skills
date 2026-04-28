#!/usr/bin/env bash
# Install Ralph into the current project. Idempotent — re-running is safe.
# Usage: install.sh [--target DIR] [--branch NAME] [--base NAME] [--force]
# Env: CLAUDE_PLUGIN_ROOT (set by Claude Code) — points at the plugin root.

set -uo pipefail

target="$PWD"
branch="ralph/work"
base="main"
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --base)   base="$2";   shift 2 ;;
    --force)  force=1;     shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$plugin_root" ]]; then
  plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
fi
assets="$plugin_root/assets"

[[ -d "$target" ]] || { echo "target not a directory: $target" >&2; exit 1; }
[[ -d "$assets/ralph" ]] || { echo "missing assets at $assets" >&2; exit 1; }

cd "$target"

copy() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && $force -eq 0 ]]; then
    echo "  skip  $dst (exists; use --force to overwrite)"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  wrote $dst"
  fi
}

echo "→ installing Ralph into $target"
echo "  branch=$branch  base=$base"

mkdir -p ralph specs
copy "$assets/ralph/once.sh"     "ralph/once.sh"
copy "$assets/ralph/afk.sh"      "ralph/afk.sh"
copy "$assets/ralph/notify.sh"   "ralph/notify.sh"
copy "$assets/ralph/README.md"   "ralph/README.md"
chmod +x ralph/once.sh ralph/afk.sh ralph/notify.sh

copy "$assets/templates/PROMPT.md"        "PROMPT.md"
copy "$assets/templates/AGENT.md"         "AGENT.md"
copy "$assets/templates/fix_plan.md"      "fix_plan.md"
copy "$assets/templates/progress.md"      "progress.md"
copy "$assets/templates/specs/README.md"  "specs/README.md"

if [[ "$branch" != "ralph/work" || "$base" != "main" ]]; then
  for f in ralph/afk.sh ralph/README.md PROMPT.md; do
    [[ -f "$f" ]] && {
      sed -i.bak -e "s|ralph/work|$branch|g" -e 's|"main"|"'"$base"'"|g' "$f"
      rm -f "$f.bak"
    }
  done
  echo "  patched branch/base in afk.sh, README, PROMPT.md"
fi

if [[ -f .gitignore ]]; then
  for line in "ralph/.state/" "tmp/"; do
    grep -qxF "$line" .gitignore || echo "$line" >> .gitignore
  done
  echo "  updated .gitignore"
else
  printf 'ralph/.state/\ntmp/\n' > .gitignore
  echo "  wrote .gitignore"
fi

if [[ -f package.json ]]; then
  if command -v jq >/dev/null; then
    tmp="$(mktemp)"
    jq '.scripts |= ((. // {}) + {"ralph":"ralph/afk.sh","ralph:once":"ralph/once.sh"})' \
      package.json > "$tmp" && mv "$tmp" package.json
    echo "  added ralph + ralph:once to package.json"
  else
    echo "  ⚠ jq not found — add these manually to package.json scripts:"
    echo '      "ralph": "ralph/afk.sh",'
    echo '      "ralph:once": "ralph/once.sh"'
  fi
else
  cat > package.json <<EOF
{
  "name": "$(basename "$target")",
  "private": true,
  "type": "module",
  "scripts": {
    "ralph": "ralph/afk.sh",
    "ralph:once": "ralph/once.sh"
  }
}
EOF
  echo "  wrote minimal package.json"
fi

cat <<'NEXT'

✓ Ralph installed.

next steps:
  1. fill in AGENT.md with your project's build/test/lint commands
  2. fill in fix_plan.md with the work items (or `gh issue list` and reference issue numbers)
  3. add specs in specs/*.md describing what "done" looks like
  4. tune PROMPT.md if needed
  5. kick the tires:    bun run ralph:once     (or: ralph/once.sh)
  6. go AFK:            bun run ralph          (or: ralph/afk.sh)

NEXT
