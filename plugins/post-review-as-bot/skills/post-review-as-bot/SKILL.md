---
name: post-review-as-bot
description: Post a code review to a GitHub PR as inline comments attributed to a GitHub App (a "[bot]" account) rather than the human running the command. The agent produces the review JSON; the bundled script validates each comment against the PR diff (dropping unplaceable ones into a notice), composes a Copilot-style body, mints an installation token from the app's private key, and submits one atomic COMMENT review. Use when asked to post a review as a bot / GitHub App.
allowed-tools: Bash(bash:*), Bash(gh:*), Bash(jq:*)
---

# post-review-as-bot

Produce a code review of the current PR, then post it as a GitHub App (the review
shows as `your-app[bot]` instead of the human who ran it).

**You generate the review** (this part is yours — read the diff, reason about the
code, write the prose + inline comments). **The script handles everything
mechanical**: it validates every comment against the PR diff, drops unplaceable
ones into a `⚠️` notice in the body, appends the `Reviewed N comments across Y
files` line + optional footer, mints the installation token, and submits ONE atomic
`event: COMMENT` review (Copilot-style — never APPROVE/REQUEST_CHANGES).

The script is **app-agnostic**: the bot identity comes entirely from environment
variables (see `README.md` for one-time GitHub App setup).

## Steps

1. Get the diff: `gh pr diff` (or `gh api /repos/{o}/{r}/pulls/{n}/files`).
2. Build a JSON object matching this schema (counts are NOT your job):

   ```jsonc
   {
     "summary": "markdown prose — overview + Changes bullets (optional)",
     "comments": [
       {
         "path": "src/foo.ts",   // required
         "line": 60,             // required — head-side line
         "side": "RIGHT",        // optional, default RIGHT
         "start_line": 56,       // optional — set with line for a range
         "start_side": "RIGHT",  // optional, default = side
         "body": "markdown comment"  // required
       }
     ]
   }
   ```

3. **Always `--dry-run` first** to inspect the exact payload, then post for real.
   The script is `scripts/gh-app-review.sh` **relative to this skill's
   directory**. Supply the app identity via env (`GH_APP_ID`,
   `GH_APP_INSTALLATION_ID`, `GH_APP_PRIVATE_KEY_PATH`). Pass through any
   `--pr <num>` / `--repo <owner/name>` / `--dry-run` flags the user gave:

   ```bash
   # dry-run needs no app identity
   echo "$REVIEW_JSON" | bash <skill-dir>/scripts/gh-app-review.sh post --dry-run [--pr N] [--repo o/n]

   # live post as your-app[bot]
   echo "$REVIEW_JSON" \
     | GH_APP_ID=123456 \
       GH_APP_INSTALLATION_ID=87654321 \
       GH_APP_PRIVATE_KEY_PATH=~/.config/my-review-bot/private-key.pem \
       GH_APP_REVIEW_FOOTER='🤖 My Review Bot' \
       bash <skill-dir>/scripts/gh-app-review.sh post [--pr N] [--repo o/n]
   ```

   (Or write the JSON to a file and pass `--input <file>` instead of piping.)

## Prerequisites

- `gh` authenticated and `jq` installed.
- A GitHub App created and installed on the target org/repo with **Pull
  requests: Read & write** permission. See `README.md` for the full setup.
- The app's private key `.pem` present locally, with `GH_APP_PRIVATE_KEY_PATH`
  pointing at it. Without the key you can only `--dry-run` — tell the user to
  generate+download the key from the app settings if a live post is wanted.
- `GH_APP_ID` and `GH_APP_INSTALLATION_ID` set to your app's values.
- `--pr` / `--repo` auto-detect from the current branch when omitted.
