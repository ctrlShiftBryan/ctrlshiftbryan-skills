---
name: pr-review-html
description: >
  Generate a single-file interactive HTML code-review artifact for a GitHub PR.
  Fetches the diff via the gh CLI, performs an honest severity-coded
  self-review, and renders an artifact with: collapsible per-file diffs with
  colored inline annotations, severity filter chips, per-finding checkboxes,
  and a "Create feedback prompt" modal that aggregates the checked items into
  a paste-ready follow-up prompt ending with "Please address this feedback.
  Address each individual item in its own conventional commit." Use this skill
  whenever the user wants to review a pull request visually, asks for an HTML
  or static review artifact, says "review PR", "review this PR", "build a PR
  review", wants color-coded findings, feedback aggregation, or a review file
  they can share — even if they don't explicitly say "HTML". Also trigger on
  "code review artifact", "interactive review", "feedback prompt for a PR",
  or when the user mentions reviewing a specific PR number.
---

# PR review HTML

Build a single self-contained HTML file that lets a reviewer (or the author)
work through a PR's diff with severity-coded inline annotations, check off
the findings they want fixed, and one-click generate a paste-ready follow-up
prompt for the next agent.

## When this skill helps

The artifact is most useful when:

- The PR has multiple files and at least a few findings worth tagging
- You want a portable review you can share, archive, or revisit
- You want to round-trip selected findings back to an LLM as a clean prompt

For very small PRs (1-2 line changes) the artifact is overkill — just leave
inline comments via `gh pr review`.

## Workflow

The skill bundles a Python build script and an HTML template. Your job is
to produce a good `findings.json` and run the script.

### Step 1 — Gather the diff and PR metadata

```bash
gh pr diff <N> > /tmp/pr-<N>.diff
gh pr view <N> --json title,headRefName,additions,deletions,files
```

Read the whole diff before you start reviewing. Note the PR number, branch
name, file count, additions, and deletions — you'll need them for the
findings JSON.

### Step 2 — Do an honest, critical self-review

For each substantive observation, assign one severity:

- **critical** — blocks merge; correctness, security, or data-loss bug
- **major** — should fix before merge; UX, partial-failure, or design
  concern
- **minor** — worth fixing but won't block; clarity, hard-coded values,
  missing edge tests
- **nit** — style, comment, or preference; take or leave
- **praise** — specifically good; call out so we keep doing it

Be honest. If you wrote the code, push back on yourself the same way you
would on a colleague. If every finding lands at "praise" you're not
reviewing — aim for a mix that includes at least a few genuine concerns
when they exist. Skip formatting nits unless they're load-bearing.

Findings can be tied to a specific file + line (rendered next to the diff)
or `general` (rendered in a "General notes" section at the bottom).

### Step 3 — Write findings.json

The full schema and a worked example live in
`references/findings-schema.md`. The shape at a glance:

```json
{
  "pr_number": 54,
  "title": "feat(scripts): pnpm onboard:dev + onboarding docs (#48 phase 1)",
  "branch": "48-onboard-dev-phase-1",
  "github_url": "https://github.com/<owner>/<repo>/pull/54",
  "files_stat": "10 files, +750 / −1",
  "verdict": "One-sentence summary of the overall take.",
  "test_commands": "pnpm test && pnpm typecheck",
  "files": [
    {
      "path": "scripts/onboard-dev.ts",
      "key": "orchestrator",
      "additions": 188,
      "deletions": 0,
      "is_new": true,
      "open_by_default": true,
      "diff": "@@ -0,0 +1,188 @@\n+import { ... }\n...",
      "annotations": [
        {
          "line": 165,
          "sev": "major",
          "title": "Manifest is mutated on `main` BEFORE the branch is created",
          "body": "If <code>openManifestPr</code> fails partway, the user is left with a dirty working tree on main.",
          "suggest": "Reorder so the branch is created first..."
        }
      ]
    }
  ],
  "general_annotations": [
    {
      "sev": "praise",
      "title": "Tests cover the surface area",
      "body": "85/85 passing; the safety-property tests are particularly nice."
    }
  ]
}
```

The `diff` field is the raw diff body for that file (everything after the
`diff --git` and index header — start at the `@@` hunk). The build script
parses `+`, `-`, and `@@` lines and renders line numbers from the new-file
side.

Body text may use inline `<code>` (renders as backticks in the aggregated
prompt) and `<em>` (renders as underscores). Keep bodies to 1-3 sentences.

`test_commands` should match whatever the target project actually uses —
the aggregated prompt tells the next agent to run them between commits.

### Step 4 — Run the build script

```bash
python "<plugin-root>/skills/pr-review-html/scripts/build_review.py" \
  --findings /tmp/pr-<N>-findings.json \
  --output plans/<unix-ts>--<m-d-h:mmam/pm>--pr-<N>-review.html
```

Get the timestamp + date label from:

```bash
date +%s
date "+%-m-%-d-%-I:%M%p" | tr 'A-Z' 'a-z'
```

The script is Python stdlib only (no pip install needed). On success it
prints the output path on stdout. Open the file in a browser to verify.

## What the artifact does

- Sticky header with PR metadata, severity filter chips, and the
  "Create feedback prompt" button
- Per-file `<details>` blocks (most substantive open by default, tests
  and wiring collapsed)
- Two-column layout: diff on the left with `+`/`-`/`@@` coloring, line
  numbers, and a severity-colored gutter bar on annotated lines; cards on
  the right with severity badge, title, body, optional suggested-fix block
- Click annotated line → scroll its card into view (and vice versa)
- Filter chips toggle visibility per severity
- Each card has a checkbox; "Create feedback prompt" aggregates checked
  items into a markdown prompt in a modal `<textarea>` with copy-to-clipboard

## Reporting back

When done, print the output path and a one-sentence verdict on the PR.
Don't proactively suggest follow-ups — the reviewer drives next steps from
the artifact.
