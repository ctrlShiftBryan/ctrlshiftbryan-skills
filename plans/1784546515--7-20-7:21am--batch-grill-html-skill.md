# Batch Grill Me HTML Skill

## Context and assumptions

- Add a new repo-local plugin named `batch-grill-me-html`, following the repository's existing Claude Code plugin layout.
- Preserve the source skill's design-tree and dependency-frontier interview model.
- Adapt each question round into a single-file local HTML form with recommended answers, optional notes, a paste-back prompt, and the required Plannotator injection script in the document head.
- Keep the skill explicitly invoked because a relentless interview should not start during ordinary conversations.
- Reuse interaction patterns proven by the repository's `questionnaire` skill while keeping this skill focused on multi-round design convergence.

## Implementation phases

1. Create the plugin manifest, skill instructions, README, and HTML round template.
2. Add the plugin to the root marketplace and README plugin table.
3. Render a representative round from the template and verify its markup, JavaScript syntax, paste-back format, manifests, and repository diff.

## Expected outcomes

- `/batch-grill-me-html` conducts a dependency-aware interview in complete frontier rounds.
- Each round opens as a portable HTML artifact with recommendations preselected.
- User answers return as one structured prompt, allowing the agent to recompute the next frontier.
- The process stops at a shared-understanding confirmation and does not begin implementation automatically.
