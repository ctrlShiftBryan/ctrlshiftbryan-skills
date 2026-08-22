# codex-native

Skills that run **inside** a Codex CLI session. Codex does the work itself — no Claude
Code orchestration, no `codex-companion.mjs` runtime, no background jobs, no
wait-or-background prompt.

This is the mirror image of [`codex-delegation`](../codex-delegation), which drives Codex
*from* Claude Code.

## Skills

| Skill | What it does |
|---|---|
| `codex-adversarial-review` | Adversarial review of uncommitted work, a branch diff, or a commit — attacks the approach, design, and assumptions rather than scanning for defects. In-session counterpart of Claude Code's `/codex:adversarial-review`. |

## Install into Codex

```
npx skills add ctrlShiftBryan/ctrlshiftbryan-skills
```

Or symlink a working copy for live edits:

```bash
ln -s "$PWD/skills/codex-adversarial-review" ~/.codex/skills/codex-adversarial-review
```

Then in a Codex session: "adversarial review my changes", or `/codex-adversarial-review`.

## Differences from `/codex:adversarial-review`

The Claude Code command wraps Codex in a runtime. Running in-session drops all of it:

| Claude Code version | In-session version |
|---|---|
| `--wait` / `--background` + an `AskUserQuestion` to choose | Runs now, in the foreground |
| Diff size estimation to pick an execution mode | Not needed |
| `--base` / `--scope` flag parsing | Target inferred from what you asked for |
| JSON against a schema, parsed by the companion script | Markdown report written straight to the session |
| Read-only enforced by the runtime | Stated as a hard constraint, verified with a `git status` before/after check |

The review prompt itself — stance, attack surface, method, finding bar, grounding — is
carried over unchanged in substance.
