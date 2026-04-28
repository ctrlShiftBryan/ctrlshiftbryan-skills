---
description: Run one Ralph iteration in the current project (HITL — kick the tires on the prompt).
argument-hint: '[--engine claude|codex] [--prompt PATH] [--log PATH]'
allowed-tools: Bash(bash:*), Bash(./ralph/once.sh:*), Bash(ralph/once.sh:*)
---

Run a single Ralph iteration:

```bash
ralph/once.sh $ARGUMENTS
```

This runs one pass of the agent against `PROMPT.md`. No looping, no branch
management, no PR. Use this to test the prompt before going AFK with
`/ralph:afk`.

If `ralph/once.sh` doesn't exist, the project hasn't installed Ralph yet —
suggest running `/ralph:install`.
