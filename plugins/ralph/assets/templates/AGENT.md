# AGENT.md — build & feedback commands

> **TODO**: replace these with your project's actual commands. Keep them
> terse — Ralph reads this every loop.

## First-time setup

```bash
# TODO: e.g. bun install / pnpm install / npm install
```

## Dev loop

```bash
# TODO: e.g. bun run dev / pnpm dev
```

## Feedback loop (run before every commit)

```bash
# TODO: e.g.
# bun run typecheck
# bun test
# bun run lint
```

**Do not commit if any check is red.** Pre-commit hooks should enforce this
once they're wired up. Until then, you (Ralph) enforce it.

## Repo conventions

- Branch: `ralph/work`. Never commit to `main`.
- Commits: conventional-ish — `feat:`, `fix:`, `chore:`, `docs:`. Include
  `Closes #<N>` trailer when finishing a GitHub issue.

## What "done" looks like

Per `specs/`. Pick the first unchecked item in `fix_plan.md`, read its spec,
implement the smallest vertical slice, verify, commit.

## Quality bar

Production-grade — this codebase will outlive the loop:

- No `TODO` / `FIXME` / `// later` / `// removed`. If it's worth a comment,
  it's worth a fix or a new `fix_plan.md` item.
- No placeholders, stubs, "implement later" branches.
- No `as any`, no `@ts-ignore`. Earn the type.
- No commented-out code.
- Function names explain what they do; no jargon-only abbreviations.
- Leave the codebase better than you found it.

Every shortcut compounds into tech debt that slows future loops down. Fight
entropy.
