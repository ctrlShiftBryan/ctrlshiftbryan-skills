# Ralph: do one thing.

The wrapper will re-invoke you after every iteration. Do **one** small,
shippable thing per loop.

## Read first (every loop)

1. `AGENT.md` — build / test / typecheck / lint commands.
2. `specs/*.md` — what "done" means. Authoritative end-state.
3. `fix_plan.md` — ordered checklist. Source of truth for what's left.
4. `progress.md` — what previous loops finished. Skim, don't re-read in full.

## Pick one task

- Open `fix_plan.md` and pick the **first unchecked** item.
- If every item is checked, output **only** `<promise>COMPLETE</promise>` and
  exit. Do nothing else. The wrapper handles the PR.
- If an item references a GitHub issue (e.g. `#7`), read its full body with
  `gh issue view <N>` (and its comments).

## Implement

- Search the codebase before assuming something isn't there. `grep`/`rg` is
  cheap; duplicate work is expensive.
- Smallest vertical slice that satisfies the item. **No placeholders, no
  TODOs, no "to be implemented later".** If you can't finish it cleanly in
  one loop, split the item into two and pick the smaller half.
- Stick to the architecture in `specs/`. If a spec is wrong, fix the spec in
  the same commit as the code change and explain why in the commit body.

## Verify

- Run the feedback loop from `AGENT.md`: typecheck → tests → lint.
- Iterate until green. **Do not commit red.** If you can't make it green,
  revert your changes (`git restore .`) and write the failure to
  `progress.md` so the next loop knows to try a different approach.

## Commit + record

- `git add` only the files you changed.
- Commit with a one-line subject naming the item, e.g.
  `feat: scaffold (#2)`. Include `Closes #<N>` as a trailer if the item
  is a GitHub issue.
- Append a block to `progress.md` (terse, sacrifice grammar for concision):

  ```
  ## <item-id> <sha>
  files: <comma-separated paths>
  decided: <one-line — non-obvious choices, "why this not that">
  blockers: <one-line, or "none">
  ```

- Tick the box in `fix_plan.md`.
- **Do not push.** **Do not merge to main.** **Do not open a PR.** The
  wrapper does all of that on COMPLETE.

## Quality bar

Production-grade. This codebase will outlive the loop:

- No `TODO` / `FIXME` / `// later`. If it's worth a comment, it's worth a
  fix or a new `fix_plan.md` item.
- No placeholders, stubs, or "to be implemented" branches.
- No `as any`, no `@ts-ignore`. Earn the type.
- No commented-out code.
- Every function has a name that explains what it does.
- Leave the codebase better than you found it.

## Then stop

End your turn. The wrapper will call you again.
