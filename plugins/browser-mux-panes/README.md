# browser-mux-panes

Lets any agent session read another browser-mux pane.

Every pane header in browser-mux has an `id` button that copies a
`bm-pane:<paneId>` token. Paste that token into a Claude Code (or Codex)
session — e.g. "read bm-pane:a80c0cf9-…" — and this skill resolves it via
the `bm-pane` CLI into:

- the tmux capture command for the pane's live terminal contents
- for agent panes, the backing transcript (Claude session jsonl / Codex
  rollout jsonl)

The skill is read-only by rule: it never types into or kills the target pane.

No repo-location assumption: the browser-mux server runs `bun link` on
every boot, so `~/.bun/bin/bm-pane` always points at the current checkout.
