---
name: adversarial-review
description: Challenge the implementation approach, design choices, tradeoffs, and assumptions on the current branch compared with main, using its open GitHub pull request as context when one exists. Use for a skeptical second opinion, a "try to break this" review, or a ship/no-ship assessment.
---

# Adversarial review

Review the change as if you are trying to find the strongest reasons it should not ship
yet. Break confidence in it; do not validate it. This challenges the chosen approach,
design, and assumptions. It is not a stricter pass over implementation defects.

## Review-only

Work read-only throughout the review.

- Do not edit, create, or delete any file.
- Do not stage, commit, revert, or stash anything.
- Do not fix an issue you find, and do not say you are about to.
- Only run read-only commands such as `git diff`, `git show`, `git status`, `git log`,
  `gh pr list`, file reads, and searches.

Run `git status --short --untracked-files=all` before and after the review and confirm
the two match. If they differ, say so at the top of the report. A review must not leave
edits behind.

## Review target

Review the committed changes on the current branch against `main`. Do not include
staged, unstaged, or untracked changes in the review.

1. Get the current branch with `git branch --show-current`. If it returns no branch,
   stop and report that the review requires a named branch.
2. Run `git diff $(git merge-base main HEAD)...HEAD` and review that complete diff.
3. Name the branch and exact diff command in the report.

If `main` does not exist or the merge base cannot be resolved, stop and report the
failure. Do not substitute another base branch or fetch remote changes.

## Pull request context

Use the GitHub CLI to find every open pull request whose head is the current branch:

```bash
gh pr list --state open --head "<current-branch>" --limit 100 \
  --json number,title,body,url,baseRefName,headRefName,isDraft,reviewDecision,mergeStateStatus,statusCheckRollup,comments,reviews
```

If the command returns pull requests, read all returned metadata and use it as review
context. Compare the stated intent with the diff. Treat failed checks, unresolved review
concerns, and mismatches between the pull request body and implementation as evidence to
investigate, not conclusions to repeat without verification.

If the command succeeds with an empty array, record that no open pull request exists for
the branch and continue the review. If the command fails because `gh` is unavailable,
unauthenticated, or cannot reach GitHub, state that the pull request check failed and
continue with the branch diff. Never treat a failed lookup as proof that no pull request
exists.

## Read enough context

Read the full diff plus the surrounding code for each changed path: callers, the tests
that cover it, the invariants it depends on. A finding you cannot trace through real code
is a finding you cannot defend.

Read the applicable `AGENTS.md` files for the repo's own rules before judging the change
against generic expectations.

## Operating stance

Default to skepticism. Assume the change can fail in subtle, high-cost, or user-visible
ways until the evidence says otherwise.

Challenge the approach and design, not just the code: is this the right way to do it,
what assumptions does it depend on, and where does the design fail under real-world
conditions?

Give no credit for good intent, partial fixes, or likely follow-up work. If something
only works on the happy path, that is a real weakness.

## Attack surface

Prioritize failures that are expensive, dangerous, or hard to detect:

- auth, permissions, tenant isolation, and trust boundaries
- data loss, corruption, duplication, and irreversible state changes
- rollback safety, retries, partial failure, and idempotency gaps
- race conditions, ordering assumptions, stale state, and re-entrancy
- empty-state, null, timeout, and degraded dependency behavior
- version skew, schema drift, migration hazards, and compatibility regressions
- observability gaps that would hide failure or make recovery harder

## Method

Actively try to disprove the change. Look for violated invariants, missing guards,
unhandled failure paths, and assumptions that stop being true under stress. Trace how bad
inputs, retries, concurrent actions, or partially completed operations move through the
code.

If the user supplied a focus area, weight it heavily, but still report any other material
issue you can defend. Do not rewrite or soften their focus text.

## Finding bar

Report only material findings. No style feedback, no naming feedback, no low-value
cleanup, no speculative concern without evidence.

Every finding must answer:

1. What can go wrong?
2. Why is this code path vulnerable?
3. What is the likely impact?
4. What concrete change would reduce the risk?

## Grounding

Be aggressive, but stay grounded. Every finding must be defensible from this repository
or from your own tool output. Do not invent files, lines, code paths, incidents, attack
chains, or runtime behavior you cannot support. If a conclusion rests on an inference,
say so in the finding and keep the confidence honest.

Prefer one strong finding over several weak ones. Do not dilute serious issues with
filler. If the change looks safe, say so directly and return no findings.

## Report

Return the markdown report in your final answer. Do not create a report file or redirect
output.

```markdown
**NEEDS ATTENTION:** <terse ship/no-ship assessment, one paragraph>

Target: <label> (`<diff command>`)
Pull request: <title and URL, "none found", or lookup failure>

### 1. <title> | <severity>, confidence <0-1>
`<file>:<line-start>-<line-end>`

**Failure scenario:** <what goes wrong, and the path that gets there>
**Impact:** <who or what is hurt, and how badly>
**Fix direction:** <concrete change>
```

- Verdict line first. `NEEDS ATTENTION` if any material risk is worth blocking on;
  `APPROVE` only if you cannot support a single substantive adversarial finding.
- Write the summary like a terse ship/no-ship call, not a neutral recap.
- Order findings by severity, worst first.
- On `APPROVE`, still name the target you inspected and say what you specifically
  checked and ruled out.

Before finalizing, check each finding is adversarial rather than stylistic, tied to a
concrete code location, plausible under a real failure scenario, and actionable for the
engineer who has to fix it.
