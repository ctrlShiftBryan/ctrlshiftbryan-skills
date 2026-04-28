# Ralph

Hands-off agentic loop. Two scripts:

- `once.sh` — one iteration. Run standalone for HITL ("kick the tires") to see
  what one loop does. Used as the inner of `afk.sh`.
- `afk.sh` — wraps `once.sh` in a loop. On clean completion, pushes the branch
  (default `ralph/work`) and opens a draft PR.

Inspired by [aihero.dev/getting-started-with-ralph][1] and the [11 tips][2].

[1]: https://www.aihero.dev/getting-started-with-ralph
[2]: https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum

## Workflow

```bash
# 1. HITL — run one iteration, eyeball the output, refine PROMPT.md, repeat.
bun run ralph:once

# 2. AFK — once you trust the prompt, walk away.
bun run ralph                          # claude, infinite, Ctrl-C to stop
bun run ralph --engine codex --max 30  # codex, capped at 30

# 3. Watch logs
tail -f ralph/.state/loop-*.log
```

The `bun run` aliases are thin wrappers around `ralph/once.sh` and
`ralph/afk.sh` — invoke the shells directly if you prefer.

## once.sh flags

| flag | default | meaning |
|---|---|---|
| `--engine` | `claude` | `claude` or `codex` |
| `--prompt` | `PROMPT.md` | path to the loop prompt |
| `--log` | (none) | tee the agent's output to this file |

## afk.sh flags

| flag | default | meaning |
|---|---|---|
| `--engine` | `claude` | `claude` or `codex` |
| `--max` | `0` (unlimited) | stop after N iterations |
| `--branch` | `ralph/work` | branch Ralph commits on |
| `--base` | `main` | base for the draft PR |
| `--sleep` | `2` | seconds between iterations |

## Stop conditions (afk.sh)

1. Agent emits `<promise>COMPLETE</promise>` → push + draft PR + notify.
2. `--max N` reached → notify only, no PR.
3. Ctrl-C → notify only, no PR.

## Permission flags (no Docker)

- `claude -p "$(cat PROMPT.md)" --dangerously-skip-permissions`
- `codex exec --dangerously-bypass-approvals-and-sandbox "$(cat PROMPT.md)"`

The article uses Docker sandbox + `--permission-mode acceptEdits`. We don't.
The dangerous bypasses are intentional.

## Requirements

- `claude` CLI logged in
- `codex` CLI logged in
- `gh` CLI logged in (`gh auth status`)
- `terminal-notifier` (`brew install terminal-notifier`)
- macOS — bell + notifier are mac-specific
