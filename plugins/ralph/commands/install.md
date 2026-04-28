---
description: Install the Ralph Wiggum agentic loop into the current project (drops ralph/ scripts, PROMPT.md, AGENT.md, fix_plan.md, progress.md, specs/README.md, plus .gitignore + package.json scripts).
argument-hint: '[--branch NAME] [--base NAME] [--force]'
allowed-tools: Bash(bash:*), Bash(jq:*), AskUserQuestion
---

Run the install script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" $ARGUMENTS
```

The script is idempotent — re-running is safe. Existing files are skipped
unless `--force` is passed.

After install, tell the user to:

1. Fill in `AGENT.md` with their project's build/test/lint commands.
2. Fill in `fix_plan.md` with the work items (or reference GitHub issues).
3. Add specs in `specs/*.md` describing what "done" looks like.
4. Tune `PROMPT.md` if needed.
5. Run `bun run ralph:once` (HITL) or `bun run ralph` (AFK) to start.

If `jq` is missing and the project already has `package.json`, the script
prints the lines the user needs to add manually.
