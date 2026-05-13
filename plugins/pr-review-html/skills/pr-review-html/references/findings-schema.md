# findings.json — schema and conventions

The build script reads a single JSON file and renders it into the HTML
template. This doc covers the exact shape, the severity rubric in more
detail, and the rules for inline HTML inside annotation bodies.

## Top-level shape

```json
{
  "pr_number": 54,
  "title": "feat(scripts): pnpm onboard:dev + onboarding docs",
  "branch": "48-onboard-dev-phase-1",
  "github_url": "https://github.com/<owner>/<repo>/pull/54",
  "files_stat": "10 files, +750 / −1",
  "verdict": "One-sentence summary of your overall take.",
  "test_commands": "pnpm test && pnpm typecheck",
  "files": [ /* see below */ ],
  "general_annotations": [ /* see below */ ]
}
```

| Field | Required | Notes |
|---|---|---|
| `pr_number` | yes | Integer or string. Used in the header and in the aggregated prompt. |
| `title` | yes | PR title, rendered as code in the header. |
| `branch` | no | Branch name, shown in the header subtitle. |
| `github_url` | no | If present, becomes a "View on GitHub" link. |
| `files_stat` | no | Free-form string like `10 files, +750 / −1` shown in the header. |
| `verdict` | no | One-sentence overall take, shown under the header. |
| `test_commands` | no | Project's test+check command. Embedded into the aggregated prompt so the next agent knows what to run. Defaults to `pnpm test && pnpm typecheck`. |
| `files` | yes | List of per-file blocks (below). |
| `general_annotations` | no | Findings not tied to a specific file/line. Rendered in a "General notes" section at the bottom. |
| `severity_counts` | no | Object with `critical`/`major`/`minor`/`nit`/`praise` counts. Computed automatically if omitted. |

## Per-file block

```json
{
  "path": "scripts/onboard-dev.ts",
  "key": "orchestrator",
  "additions": 188,
  "deletions": 0,
  "is_new": true,
  "open_by_default": true,
  "diff": "@@ -0,0 +1,188 @@\n+import { ... }\n...",
  "annotations": [ /* see below */ ]
}
```

| Field | Required | Notes |
|---|---|---|
| `path` | yes | Path shown in the file's `<summary>`. |
| `key` | no | Short unique identifier used in DOM IDs. Auto-assigned if omitted (`file-0`, `file-1`, …). Provide your own when you want stable IDs — for example, if you regenerate the artifact and want browser scroll position to be preserved. |
| `additions` | no | Integer; shown as `+N` in summary. |
| `deletions` | no | Integer; shown as `−N` in summary. |
| `is_new` | no | If true, the path gets an italicized "(new file)" suffix. |
| `open_by_default` | no | If true, the `<details>` starts expanded. Use for the most substantive 2-3 files; leave tests/wiring collapsed. |
| `diff` | yes | The raw diff body, starting at the first `@@` hunk. Don't include the `diff --git` / `index` header lines. |
| `annotations` | no | Findings tied to specific new-file line numbers. |

### What goes in `diff`

Take the chunk of `gh pr diff <N>` output between this file's header and
the next file's header. Strip the `diff --git`, `index`, `---`, `+++`,
and `new file mode` lines. Keep everything from the first `@@` onward.

The template parses lines as follows:

- Lines starting with `+` are additions (green tint, increment the
  new-file line counter)
- Lines starting with `-` are deletions (red tint, no line increment)
- Lines starting with `@@` are hunks; the parser reads `+N` to know
  where the new-file line numbering resumes
- Anything else is context (white, increments the counter)

### Truncating long files

For very long diffs you don't want to render in full, you can truncate
the `diff` field and add a context paragraph instead — the template will
render whatever you give it. The annotations referencing trimmed lines
will simply have nothing to highlight in the diff.

If a file is mostly noise (auto-generated lockfile changes, formatting
sweeps), consider grouping it under a single "tests &amp; misc" entry
with a brief explanation in the diff field instead of the raw diff.

## Annotation block

```json
{
  "line": 165,
  "sev": "major",
  "title": "Manifest is mutated on `main` BEFORE the branch is created",
  "body": "If <code>openManifestPr</code> fails partway, the user is left with a dirty working tree on main.",
  "suggest": "Reorder so the branch is created first:\n  1. git checkout -b onboard/<username>\n  2. appendDeveloperToFile(...)\n  3. git add / commit / push / gh pr create"
}
```

| Field | Required | Notes |
|---|---|---|
| `line` | no (file annotations) / never (general) | New-file line number. Omit for general annotations. |
| `sev` | yes | One of `critical`, `major`, `minor`, `nit`, `praise`. |
| `title` | yes | Short title (≤80 chars works best). Plain text or simple inline HTML. |
| `body` | yes | 1-3 sentences. Inline HTML allowed — see "HTML in bodies" below. |
| `suggest` | no | Multi-line suggested-fix block. Rendered as a monospace pre-wrap block. Plain text only; not HTML. |

## HTML in bodies

The template allows inline HTML inside `title` and `body`. Two tags are
specifically translated when you click "Create feedback prompt":

- `<code>foo</code>` → `` `foo` `` (markdown backticks)
- `<em>foo</em>` or `<i>foo</i>` → `_foo_` (markdown underscores)

Other tags survive as plain text via `textContent`, so they render fine
in the HTML view but contribute their text to the aggregated prompt
without markup. Avoid block-level HTML (`<div>`, `<p>`) in bodies — keep
it inline.

Always escape user-controlled content. Since these are review notes
authored by Claude, that's a non-issue in practice, but don't paste raw
file content (which may contain `<` and `&`) into a body without
sanitizing — wrap it in `<code>` so it reads as code anyway.

## Severity rubric

Pick one severity per finding. The rubric below is calibrated to help
keep the distribution useful — if everything ends up "praise" or
"critical", the artifact loses its signal.

### critical

Blocks merge. Correctness, security, data-loss, or "this can never go
to production" tier. Use sparingly — typical PRs have zero.

**Examples:**

- SQL injection in a user-input path
- Race condition that can corrupt persisted state
- Migration that drops a column without a backfill
- Auth bypass

### major

Should fix before merge. Not a bug-bug, but a partial-failure, UX, or
design-level concern that the author would want to know about. Typical
PRs have 0-2.

**Examples:**

- Side effect ordered such that a mid-flight failure leaves the user in
  a broken state with no rollback
- A flag named `--force` that doesn't actually force anything (the
  finding in our worked example)
- A migration that's safe in isolation but unsafe given a known
  concurrent process

### minor

Worth fixing but won't block merge. Code clarity, hard-coded values
that should be configurable, missing test on a non-trivial edge case,
inconsistency with surrounding code patterns.

**Examples:**

- Magic constant that should be a named export
- A pre-check that asserts something the script never actually uses
- A regex that's stricter or looser than its JSDoc claims
- Local helper that duplicates a helper in another file

### nit

Style, comment, preference, or aesthetic. Reviewer take-it-or-leave-it.
Don't load up on these — three is usually plenty.

**Examples:**

- "This comment is borderline-deletable per your no-comments default"
- "Consider naming this `Args` instead of `Options`"
- Trailing whitespace / formatting (only if it's load-bearing somehow)

### praise

Specifically good — call out so the team keeps doing it. Aim for 3-6
per substantive PR. Praise the *pattern*, not just "looks good".

**Examples:**

- "`satisfies` type-guard catches structural drift if Developer ever
  gains a required field"
- "Manifest re-validated through the canonical validator — cheap
  defense in depth"
- "Rollback-on-failure test asserts a safety property, not just
  happy-path"

## A worked example

A minimal but complete `findings.json`:

```json
{
  "pr_number": 999,
  "title": "feat: example PR",
  "branch": "feat/example",
  "github_url": "https://github.com/owner/repo/pull/999",
  "files_stat": "1 file, +5 / −0",
  "verdict": "Tiny example — one major finding worth a fix.",
  "test_commands": "pnpm test",
  "files": [
    {
      "path": "src/example.ts",
      "key": "example",
      "additions": 5,
      "deletions": 0,
      "is_new": true,
      "open_by_default": true,
      "diff": "@@ -0,0 +1,5 @@\n+export function add(a: number, b: number): number {\n+  // TODO handle bigint\n+  return a + b;\n+}\n+",
      "annotations": [
        {
          "line": 3,
          "sev": "major",
          "title": "`add` silently coerces large numbers — should reject or accept `bigint`",
          "body": "Inputs >2^53 lose precision. Either narrow the type to a safe range, or accept <code>bigint</code> as the TODO suggests.",
          "suggest": "function add(a: number, b: number): number {\n  if (!Number.isSafeInteger(a) || !Number.isSafeInteger(b)) {\n    throw new RangeError('inputs must be safe integers');\n  }\n  return a + b;\n}"
        }
      ]
    }
  ],
  "general_annotations": [
    {
      "sev": "praise",
      "title": "PR scope is well-bounded",
      "body": "Single function, single test, single concern. Easy to review."
    }
  ]
}
```

Run:

```bash
python build_review.py --findings findings.json --output review.html
```
