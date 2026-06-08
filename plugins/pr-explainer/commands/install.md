---
description: Install the AI PR-explainer GitHub Action into the current repo (workflow + check/publish scripts, orphan ai-docs branch, GitHub Pages, repo-specific config). Manual setup — never auto-triggered.
argument-hint: '[--target DIR] [--base NAME] [--ai-branch NAME] [--explainer-dir NAME] [--no-bootstrap] [--no-pages] [--force]'
allowed-tools: Bash(bash:*), Bash(gh:*), Bash(git:*), Bash(jq:*), AskUserQuestion
---

Install the PR-explainer GitHub Action into the current repository.

First, confirm the prerequisites and tell the user what will change on their
GitHub repo (this creates an `ai-docs` branch, enables GitHub Pages, and the
workflow will post a status check on PRs — all real, outward-facing changes):

- inside a git repo with a GitHub `origin` remote they can push to
- `gh` CLI authenticated (`gh auth status`)
- Actions workflow permissions set to read/write
- Pages available on their plan

Then run the installer:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/install-pr-explainer/scripts/install.sh" $ARGUMENTS
```

The script is idempotent — re-running is safe; existing files are skipped
unless `--force`. If `gh` is unavailable, pass `--no-pages --no-bootstrap` to
degrade to a files-only install.

After it finishes, relay the printed next steps: commit + push on the base
branch, open/refresh a PR, then generate + publish the explainer (the bot
comment carries the exact prompt and publish command). If `PAGES_BASE` was left
unset because Pages wasn't live yet, tell the user to re-run the installer once
Pages finishes provisioning. Full design + troubleshooting live in the
installed `docs/pr-explainer.md`.
