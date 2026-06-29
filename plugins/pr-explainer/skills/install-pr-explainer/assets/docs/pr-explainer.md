# PR explainers

Every PR should carry an AI-generated HTML "explainer" — a visual walkthrough
of what the PR does, plus the critical steps to verify it by hand. A bot comment
on the PR nags you until one exists, then links the published copy.

> Installed by the `pr-explainer` plugin. The `__TOKEN__`-style values below are
> filled in for this repo at install time.

There are two halves:

1. **You generate the explainer** — run the generation prompt below in Claude
   Code; it writes one HTML file into `__EXPLAINER_DIR__/`.
2. **You publish it** — `__PUBLISH_CMD__` pushes that file to the
   `__AI_BRANCH__` branch, which GitHub Pages serves. The bot comment turns green.

---

## The three states

The bot keys everything off the PR's **net-diff identity** (`DIFF_ID`) rather
than the head commit SHA. `DIFF_ID` is the first 12 chars of
`git patch-id --stable` over `origin/__BASE_BRANCH__...<head>`. `patch-id` is
invariant to `@@` line-number shifts, so merging `__BASE_BRANCH__` in (which
moves the head SHA but not the PR's actual changes) yields the **same** `DIFF_ID`
and a published explainer stays green.

On every PR event — and again whenever an explainer lands on `__AI_BRANCH__` —
the bot re-evaluates and rewrites a single sticky comment:

| State         | Meaning                                                                            |
| ------------- | ---------------------------------------------------------------------------------- |
| 🔴 **red**    | No explainer exists for this PR at all. Generate one.                              |
| 🟡 **yellow** | An explainer exists for an **older** `DIFF_ID` of this PR, but not the current one. |
| 🟢 **green**  | An explainer exists for the current `DIFF_ID`. Linked and live.                    |

Red and yellow comments embed the generation prompt and the publish command.
Green links the rendered explainer plus a "(source)" link to the file on
`__AI_BRANCH__`.

Independently of the comment, the bot posts a `pr-explainer` **commit status** to
the PR head SHA — success for green, failure for yellow/red. That status (not the
job exit code) is the gating check on the PR.

---

## Filename format

One file per net-diff identity, named with the PR number and the `DIFF_ID`:

```
__EXPLAINER_DIR__/<PR#>-<DIFF_ID>-explainer.html
```

For example, PR #101 with diff id `bff96aa3c1d2`:

```
__EXPLAINER_DIR__/101-bff96aa3c1d2-explainer.html
```

When you push commits that change the PR's actual diff, the `DIFF_ID` changes,
the existing file goes stale (🟡), and you regenerate against the new id. A
no-op `__BASE_BRANCH__` merge alone does **not** change the `DIFF_ID`.

---

## 1. Generate it

Run the generation prompt against the PR branch in Claude Code. Easiest path:
copy it straight from the red/yellow bot comment — it already has the concrete
filename (PR number + current `DIFF_ID`) and the PR link filled in.

The prompt is a single source of truth at
[`.github/prompts/explainer-generation.md`](../.github/prompts/explainer-generation.md)
(the bot comment embeds it verbatim, filling in the per-PR filename and PR URL).
It instructs the generated HTML to:

- include the [Plannotator](https://plannotator.ai) inject `<script>` in its
  `<head>`, so the published explainer can be annotated; and
- carry a clickable link back to the PR near the top.

It writes one file to `__EXPLAINER_DIR__/<PR#>-<DIFF_ID>-explainer.html`.

## 2. Publish it

```bash
__PUBLISH_CMD__
```

This computes the `DIFF_ID`, commits the file you just generated onto the
`__AI_BRANCH__` branch in a throwaway worktree, and pushes it. Within ~30–60s
GitHub Pages goes live and the next workflow run flips the PR comment to green.

---

## How the pieces fit

- **Orphan `__AI_BRANCH__` branch** — a docs-only branch with no app history. It
  holds `__EXPLAINER_DIR__/` plus a tiny landing page and a `.nojekyll` marker (so
  Pages serves the raw HTML verbatim). `__PUBLISH_CMD__` is the only thing that
  writes to it, and it also mirrors the current workflow + check script into the
  branch on every publish (push events run the workflow file **from** the pushed
  branch, so it must carry the up-to-date copies).
- **GitHub Pages** — serves that branch (deploy-from-branch) at the repo's Pages
  URL. Private repos get a randomized `*.pages.github.io` subdomain (org-only),
  not `<org>.github.io/<repo>`. A rendered explainer is at
  `…/__EXPLAINER_DIR__/<file>`. Look the base up anytime with
  `gh api repos/:owner/:repo/pages --jq .html_url`.
- **Dual trigger** — the nag workflow runs on two events:
  - `pull_request` (opened / reopened / synchronize) — evaluates that one PR
    against its current diff and upserts its comment.
  - `push` to `__AI_BRANCH__` — when an explainer lands, the workflow maps the
    changed file(s) back to their PR number(s), checks each is still open, and
    re-evaluates so the just-published PR flips to green without waiting for the
    next PR event.
- **Existence check** — the workflow never checks out `__AI_BRANCH__`. It lists
  `__EXPLAINER_DIR__/` over the GitHub REST contents API (`gh api …`), so a
  missing folder is just "empty," not an error.

---

## Why `__EXPLAINER_DIR__/` is gitignored on `__BASE_BRANCH__`

Explainers are tracked **only** on the `__AI_BRANCH__` branch — that is their
home and where Pages serves them from. On `__BASE_BRANCH__` the directory is
gitignored so the files you generate locally never get committed into app
history. This keeps app PRs free of large generated HTML and keeps a single
source of truth for each explainer on `__AI_BRANCH__`. The `__AI_BRANCH__`
branch ships its own `.gitignore` that deliberately does **not** ignore
`__EXPLAINER_DIR__/`.

---

## Troubleshooting

| Symptom                                        | Fix                                                                       |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| Comment still 🔴 after publishing              | Confirm the filename's `DIFF_ID` matches the **current** one in the comment. |
| Comment 🟡 after pushing new commits           | Expected — the PR's diff changed. Regenerate and republish.               |
| Rendered link 404s right after publishing      | Pages takes ~30–60s to go live; refresh.                                  |
| `__PUBLISH_CMD__` finds nothing to push        | Generate the HTML into `__EXPLAINER_DIR__/` first (step 1).               |
| Status check stuck failing, no comment         | Confirm Actions has read/write workflow permissions and the workflow ran. |
