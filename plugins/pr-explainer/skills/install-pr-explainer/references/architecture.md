# pr-explainer architecture

Deep reference for the agent running the install skill. Names below use the
defaults (`main` base, `ai-docs` docs branch, `html-explainers/` dir); the
installer substitutes whatever the repo actually uses.

## The two halves

**1. Nag + gate** — `.github/workflows/pr-explainer.yml` →
`.github/scripts/pr-explainer-check.sh`.

Runs on `pull_request` (opened/reopened/synchronize) against the base branch,
and on `push` to `ai-docs`. For the PR it computes a **DIFF_ID** and upserts a
single sticky comment plus a `pr-explainer` **commit status** on the head SHA.

**2. Publish** — `scripts/explainer-publish.sh` (wrapped as the
`explainer:publish` package script, or run directly with bash).

Computes the same DIFF_ID, drops the generated HTML into a throwaway worktree of
`ai-docs`, mirrors the current workflow + check script into that branch, commits
and pushes. GitHub Pages serves it; the push re-runs the workflow from `ai-docs`.

## DIFF_ID, not head SHA — why it matters

`DIFF_ID` = first 12 chars of `git patch-id --stable` over
`origin/main...<head>`. `patch-id` is invariant to `@@` line-number shifts, so
merging `main` into the PR branch (which moves the head SHA but not the PR's
actual changes) yields the **same** DIFF_ID. A published explainer therefore
stays green across no-op base merges. Publish and check compute it **identically**
(both use `git diff --full-index ... | git patch-id --stable`) so they always
agree on the filename `html-explainers/<PR#>-<DIFF_ID>-explainer.html`.

The check script's `compute_diff_id()` and the publish script's DIFF_ID block
MUST stay byte-for-byte aligned. Don't edit one without the other.

## The three states

- 🟢 **green** — a file for the current DIFF_ID exists on `ai-docs`. Comment
  links it; status = success (target_url = the rendered Pages URL).
- 🟡 **yellow** — a file exists for an *older* DIFF_ID of this PR. Comment shows
  the stale link + the regeneration prompt; status = failure.
- 🔴 **red** — no file for this PR at all. Comment embeds the generation prompt;
  status = failure.

## Why the commit status is the gate (not the job exit code)

The job always exits 0 (except on a broken-gate infra error). Gating is done by
the per-head-SHA `pr-explainer` commit status. Because that status is keyed on
the head SHA, the `push`-to-`ai-docs` run that fires right after publish can
re-post **success** on that same SHA and flip the check green with **no new
commit on the PR**. A non-zero job exit would instead create a workflow check
that the publish run couldn't clear. This is the crux of the design — preserve
it.

## Why `push` to `ai-docs` re-greens the PR

GitHub runs a `push` event's workflow from the *pushed* ref. So the workflow
file must live on `ai-docs`. The publish script mirrors
`.github/workflows/pr-explainer.yml` + `.github/scripts/pr-explainer-check.sh`
into `ai-docs` **in the same commit** as the explainer, so the push that lands
the explainer also carries the workflow that evaluates it. The push handler maps
changed `html-explainers/<PR#>-…` files back to PR numbers, confirms each PR is
open, and re-evaluates → green.

Consequence for install: the bootstrap commit does **not** need to pre-place the
workflow on `ai-docs`. The first publish brings it (with the correct,
already-substituted `PAGES_BASE`). The installer only seeds `ai-docs` with
`.nojekyll`, a landing page, a permissive `.gitignore`, and an empty
`html-explainers/`.

## GitHub Pages

Deploy-from-branch on `ai-docs`, path `/`. `.nojekyll` makes Pages serve raw
HTML verbatim. Public repos get `https://<owner>.github.io/<repo>`; **private**
repos get a randomized `https://<random>.pages.github.io` (org-only). The
installer reads whatever `gh api repos/:owner/:repo/pages --jq .html_url`
returns, so both work — but `html_url` can be empty for the first few seconds
after enabling, which is why the installer polls. If it's still empty, it leaves
`PAGES_BASE` as a token and tells the user to re-run.

## Footprint the installer creates

On the base branch (committed by the user):
`.github/workflows/pr-explainer.yml`, `.github/scripts/pr-explainer-check.sh`,
`scripts/explainer-publish.sh`, `docs/pr-explainer.md`, a `.gitignore` entry for
`html-explainers/`, and (if present) a `package.json` `explainer:publish` script.

On `origin` directly (pushed by the installer): the orphan `ai-docs` branch and
the GitHub Pages site.

## Common failure modes to watch for

- **Status check never appears** → repo Actions workflow permissions are
  read-only. The workflow's `permissions:` block requests writes but an
  org/repo policy can cap it. Fix: Settings → Actions → General → Workflow
  permissions → read/write.
- **Pages enable returns 403/404** → private repo on a plan without Pages, or
  insufficient admin rights. Degrade with `--no-pages` and have the user enable
  it by hand, then re-run to fill `PAGES_BASE`.
- **Fork PRs** show no comment by design — the workflow's `if:` skips PRs whose
  head repo isn't the base repo (the read-only fork token can't upsert).
- **`bootstrap` says branch exists** → expected on re-install or if the same
  GitHub repo was set up from another worktree; idempotent, safe.
- **Publish "finds nothing to push"** → the HTML wasn't generated into
  `html-explainers/` first, or its DIFF_ID doesn't match the current one.
