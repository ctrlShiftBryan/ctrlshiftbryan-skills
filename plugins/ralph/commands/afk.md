---
description: Start the Ralph AFK loop in the current project. Runs until <promise>COMPLETE</promise>, --max, or Ctrl-C; opens a draft PR on COMPLETE.
argument-hint: '[--engine claude|codex] [--max N] [--branch NAME] [--base NAME] [--sleep N]'
allowed-tools: Bash(bash:*), Bash(./ralph/afk.sh:*), Bash(ralph/afk.sh:*)
---

Start the AFK loop:

```bash
ralph/afk.sh $ARGUMENTS
```

Defaults: `--engine claude`, `--max 0` (infinite), `--branch ralph/work`,
`--base main`, `--sleep 2`.

Stop conditions:
1. Agent emits `<promise>COMPLETE</promise>` → push branch + draft PR + notify.
2. `--max N` reached → notify only, no PR.
3. Ctrl-C → notify only, no PR.

Per-loop output is teed to `ralph/.state/loop-NNN.log`.

If `ralph/afk.sh` doesn't exist, the project hasn't installed Ralph yet —
suggest running `/ralph:install`.
