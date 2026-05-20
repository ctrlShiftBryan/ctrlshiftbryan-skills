---
name: review-address
description: "Reply to every PR review comment — from GitHub Copilot, other review bots, and human reviewers — with code fixes or reasoned push-backs. Fetches all comments via the GitHub API, triages each one, fixes code, commits, and posts an inline reply to every comment. Use whenever the user wants to address PR feedback, respond to review comments, handle Copilot's review, clear out reviewer comments, or says 'address the review', 'reply to the comments', 'handle the PR feedback' — even if no specific reviewer is named. Not complete until every comment has a response posted."
---

# Review Address — Reply to Every PR Review Comment

**Goal: Post an inline reply to every reviewer comment on the PR.** Code fixes and push-backs are the content of those replies — but the replies themselves are the deliverable. The skill is NOT complete until every comment has a response posted via the GitHub API.

This applies equally to GitHub Copilot's review comments, other review bots, and human reviewers — every non-author comment gets a reply.

## Process (Default — Not in Plan Mode)

### 1. Detect PR

```bash
gh pr view --json number,author -q '{number: .number, author: .author.login}'
```

Capture PR number + PR_AUTHOR. Stop with message if no open PR on current branch.

### 2. Fetch & Process All Comments

Get owner/repo from `gh repo view --json owner,name`.

Three paginated API calls (no login filter):

- **Review comments (inline):**
  ```bash
  gh api repos/{owner}/{repo}/pulls/$PR/comments --paginate
  ```
- **Issue comments (top-level):**
  ```bash
  gh api repos/{owner}/{repo}/issues/$PR/comments --paginate
  ```
- **Reviews (for reviewer identity):**
  ```bash
  gh api repos/{owner}/{repo}/pulls/$PR/reviews --paginate
  ```

Discard all comments where `.user.login == PR_AUTHOR`.

Keep every review comment where `.user.login != PR_AUTHOR`. Compute `handled_by_author` (whether PR_AUTHOR already replied in thread) only as metadata for reply wording — never skip a comment because of it.

- **Inline comments:** check `in_reply_to_id` chain for a reply where `.user.login == PR_AUTHOR` → set `handled_by_author: true`
- **Top-level comments:** check subsequent comments by PR_AUTHOR → set `handled_by_author: true`

Display comments grouped by `user.login` for triage clarity:

- Bots first (logins ending in `[bot]`)
- Then humans alphabetically

GitHub Copilot's review comments come from the login `copilot-pull-request-reviewer[bot]` — it's just another bot reviewer, so it sorts into the bots group and gets triaged and replied to like any other.

Triage every kept comment (address or push back), even if already handled/resolved.

### 3. Make Code Fixes

For each comment triaged as "address":

- Make the minimal KISS fix in the code
- No distinction between bot/human

For push-backs: prepare clear reasoning response (no code changes).

### 4. Commit & Push

Only if code changes were made. Write a **conventional commit** that describes the actual fixes — not a static placeholder. The single commit covers everything from Step 3.

- **Type**: pick from `fix` / `refactor` / `perf` / `docs` / `test` / `style` / `chore` based on what the changes actually did. If the addressed comments are a mix, use the type of the most significant change and mention the rest in the body.
- **Scope** (optional): the module / area touched (e.g. `auth`, `api`, `parser`). Omit if changes span many areas.
- **Subject**: imperative, lowercase, no period, ≤72 chars, summarizing the substance of the fix — not "address PR review feedback".
- **Body** (optional, blank line after subject): bulleted list when several distinct comments were addressed in one commit.

```bash
git add -A
git commit -m "<type>(<scope>): <imperative summary of the fix>" \
           -m "- <comment 1 — what changed>" \
           -m "- <comment 2 — what changed>"
git push
```

**Examples:**

- `fix(auth): reject empty bearer tokens before signature check`
- `refactor(parser): extract token loop into iterator to fix off-by-one`
- `perf(api): memoize permission lookups noted in review`

Skip this step entirely if all comments were push-backs (no code changes).

### 5. Reply to Every Comment

**This is the primary deliverable.** Reply to every triaged comment via appropriate endpoint:

- **Inline comments:**
  ```bash
  gh api repos/{owner}/{repo}/pulls/$PR/comments/{id}/replies -X POST -f body="Fixed — [brief description]"
  ```
- **Top-level comments:**
  ```bash
  gh api repos/{owner}/{repo}/issues/$PR/comments -X POST -f body="[response]"
  ```

For addressed items: "Fixed — [brief description]"
For push-backs: clear reasoning why the suggestion was declined.

**Do not proceed to the next step until every comment has a reply posted.**

### 6. Re-review Prompt (conditional)

After all replies posted, if any **human** reviewers (non-bot) had comments that were **addressed** (not pushed back):

Use `AskUserQuestion` to ask if the user wants to request re-review from those specific humans. List each human reviewer whose feedback was addressed.

For each selected reviewer:

```bash
gh api repos/{owner}/{repo}/pulls/$PR/requested_reviewers -X POST --field "reviewers[]={login}"
```

Skip entirely if no human reviewers had comments addressed.

## Completion Checklist (must all be true)

- [ ] Every reviewer comment has an inline reply posted via `gh api`
- [ ] Code fixes committed and pushed (if any)

**If replies are not posted, the skill has NOT been executed.**

## Plan Mode Behavior

If triggered while in plan mode: **do not act**. Instead produce a triage table grouped by reviewer listing each comment, the decision (address/push-back), and proposed change or reasoning.

## Principles

- **Replies are the output** — code fixes support replies, not the other way around
- **Re-runnable means safe to run repeatedly** — not "skip handled"
- **KISS** — minimal fixes, no over-engineering
- **Push back when warranted** — not all suggestions are improvements
- **Single commit** — one commit for all fixes
- **Reviewer-grouped** — triage organized by commenter for clarity

## Edge Cases

| Condition                    | Handling                                 |
| ---------------------------- | ---------------------------------------- |
| No open PR                   | stop with message                        |
| No review comments           | stop with message                        |
| All from PR author           | stop: "no reviewer comments to address"  |
| All previously handled       | still reply to all with follow-up status |
| All push-backs               | skip commit/push, only reply             |
| No human reviewers addressed | skip re-review prompt                    |
