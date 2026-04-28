---
name: install-ralph
description: Install Matt Pocock / Geoffrey Huntley's Ralph Wiggum agentic loop into a project. Drops ralph/{once,afk,notify}.sh, PROMPT.md, AGENT.md, fix_plan.md, progress.md, specs/README.md, plus .gitignore entries and package.json scripts (ralph, ralph:once). Use this skill whenever the user asks to install/set-up/add Ralph, the ralph wiggum loop, or an AFK agentic loop, or when they mention wanting an autonomous coding loop with claude/codex CLI bypassing permissions, or porting a Ralph setup to another repo.
---

# Install Ralph

Install the Ralph Wiggum agentic loop (claude or codex) into the user's
current project.

## When to trigger

- "install ralph" / "set up ralph" / "add ralph" / "scaffold ralph"
- "ralph wiggum loop" / "afk loop" / "autonomous coding loop"
- "I want claude to keep coding" / "I want codex to loop on this"
- User has read https://www.aihero.dev/getting-started-with-ralph and wants
  the same setup in their repo.

## Approach

The plugin already has a `/ralph:install` slash command that does the work.
The right behavior is usually to invoke that command directly:

```
Tell the user: "Running /ralph:install into the current project."
Then run: bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"
```

`${CLAUDE_PLUGIN_ROOT}` resolves to this plugin's root when running inside
Claude Code.

## What the install does

1. Creates `ralph/` and `specs/` directories.
2. Copies `ralph/once.sh`, `ralph/afk.sh`, `ralph/notify.sh`,
   `ralph/README.md`. `chmod +x` the scripts.
3. Copies `PROMPT.md`, `AGENT.md`, `fix_plan.md`, `progress.md`,
   `specs/README.md` (with TODO markers the user fills in).
4. Adds `ralph/.state/` and `tmp/` to `.gitignore` (creates it if missing).
5. Adds `"ralph": "ralph/afk.sh"` and `"ralph:once": "ralph/once.sh"` to
   `package.json` scripts (creates a minimal one if missing).
6. Prints next steps.

## Flags

- `--branch NAME` — branch Ralph commits on. Default `ralph/work`.
- `--base NAME` — base branch the draft PR targets. Default `main`.
- `--force` — overwrite existing files. By default, existing files are
  skipped (the install is idempotent).

## After install

Tell the user the four things they need to fill in:

1. `AGENT.md` — replace the TODO blocks with their build/test/lint commands.
2. `fix_plan.md` — replace the example items with real work (or GitHub
   issue references like `#7`).
3. `specs/*.md` — write 1-4 short specs describing the end state.
4. `PROMPT.md` — usually fine as-is; tune if their workflow differs.

Then suggest: `bun run ralph:once` to kick the tires (HITL), then
`bun run ralph` to go AFK.

## Permission flags (no Docker)

Ralph runs the agent CLI with permission bypasses, by design — no Docker
sandbox, no `acceptEdits`. The user has explicitly opted into this.

- `claude -p "$(cat PROMPT.md)" --dangerously-skip-permissions`
- `codex exec --dangerously-bypass-approvals-and-sandbox "$(cat PROMPT.md)"`

If the user expresses concern about safety, point them at the article's
recommendation to use `docker sandbox run claude` instead. The skill itself
does not install the safer mode.
