---
name: browser-mux-panes
description: >
  Use whenever the prompt contains a `bm-pane:<id>` token, or the user asks to
  read/look at "my other pane", "my other terminal", or another Claude/Codex
  session in browser-mux. The token is copied from a pane header's "id" button
  and identifies one browser-mux pane. This skill resolves it into the pane's
  live terminal contents (tmux capture) or the backing agent transcript.
---

# Reading a browser-mux pane from its `bm-pane:` token

Every browser-mux pane runs in its own tmux server. A `bm-pane:<paneId>`
token is enough to find everything about it.

The resolver is the `bm-pane` bin, which the browser-mux server registers
globally (`bun link` → `~/.bun/bin/bm-pane`) on every boot — no assumption
about where the repo lives.

## Steps

1. Resolve the token (first form that exists wins — `~/.bun/bin` is often
   not on PATH):

   ```bash
   bm-pane bm-pane:<paneId>
   ~/.bun/bin/bm-pane bm-pane:<paneId>
   ```

   If neither exists, run `bun link` once inside the browser-mux repo (its
   registered location: `readlink ~/.bun/install/global/node_modules/browser-mux`),
   or fall back to tmux-only reading (step 2 — socket and session derive
   from the id alone: `browser-mux-pane-<id>` / `pane-<id>`).

   Returns JSON:
   - `tmux.captureCommand` — ready-to-run command for the live screen +
     scrollback
   - `paneType` — `terminal` or `agent-terminal`; `title`, `cwd`, `lifecycle`
   - `agent` — for agent panes: `provider` (`claude-code` / `codex-cli`),
     `conversationId`, `transcriptPath` (Claude session jsonl or Codex
     rollout jsonl), `transcriptExists`
   - `warning` — non-null when the Work Session lookup failed; the `tmux`
     block is still valid because it derives from the id alone.

2. Read what the user asked for:
   - **Terminal contents** (any pane kind): run `tmux.captureCommand`.
     Increase scrollback by changing `-S -1000` (e.g. `-S -5000`); `-S -`
     captures everything.
   - **Agent conversation**: read `agent.transcriptPath`. These are JSONL
     event logs — usually `tail` the last N lines or grep rather than
     reading the whole file. The live screen capture is often sufficient
     and much cheaper.

3. Summarize or quote the captured output as the user's task requires.

## Rules

- **Read-only.** Never run `tmux send-keys`, `attach`, `kill-session`, or
  write to the pane unless the user explicitly asks you to interact with it.
- Don't guess socket/session names — always take them from the resolver
  output (`socket` is `browser-mux-pane-<id>`, session `pane-<id>`, but the
  resolver is the source of truth).
- A bare pane id without the `bm-pane:` prefix works too if the user
  clearly means a browser-mux pane.
