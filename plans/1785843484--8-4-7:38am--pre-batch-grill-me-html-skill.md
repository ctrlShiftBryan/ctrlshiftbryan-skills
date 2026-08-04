# pre-batch-grill-me-html skill

Design settled via a batch-grill-me-html session (2 rounds, all recommendations accepted).

## Goal

New self-contained plugin/skill that pre-generates the *entire* grilling interview up-front and delivers it as one all-rounds HTML form, instead of one round per turn.

## Decisions

1. **build-1** Self-contained fork of batch-grill-me-html (own SKILL.md + own template, no shared assets).
2. **ui-1** One long scrollable page; rounds as labeled stacked sections.
3. **dep-1** A deviation locks the full transitive closure of dependent questions.
4. **gen-1** Pre-generate to full depth until the recommended-path frontier is empty.
5. **gen-2** All research the recommended path needs runs before the form opens.
6. **out-1** After a deviated pass, re-run full pre-generation on the remaining tree; open another all-rounds form.
7. **out-2** Even a clean all-recommended pass ends with a final synthesis the user explicitly confirms.
8. **dep-2** One lock label: "Impacted by your answer to X — needs revisiting"; read-only, comment box stays editable.
9. **dep-3** Deviation = non-recommended or "Other" selection only. Comments never lock; model resolves comment conflicts after submit.
10. **ui-2** Every question with dependents shows an "affects …" chip up-front (blast radius before deviating).
11. **out-3** Deviated-pass prompt contains everything: confirmed answers, deviations with new answers, locked IDs with comments, all other comments.
12. **out-4** After a rebuild, still-valid answers move to the settled panel; the new form contains only rebuilt + previously-locked questions.

## Excluded

Per-option impact maps, two-tier lock labels, depth caps, wizard layout, comment-triggered locking, shared assets with batch-grill-me-html.

## Risks

- Up-front generation slow on deep trees (accepted).
- Transitive-closure locking is conservative; may cost an extra rebuild cycle.
- Base template's same-frontier prerequisite rejection must be inverted: cross-round prerequisites inside one file are the point. Forward/same-round references remain errors.

## Build steps

1. `plugins/pre-batch-grill-me-html/` — plugin.json, README, `skills/pre-batch-grill-me-html/SKILL.md`, `assets/allrounds.html`.
2. Register in `.claude-plugin/marketplace.json`.
3. Install: copy to `~/.agents/skills/pre-batch-grill-me-html`, symlink from `~/.claude/skills/`.
4. Smoke test: node --check the inline script; open a demo filled form in browser-mux.
