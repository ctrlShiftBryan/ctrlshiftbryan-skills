# post-review-as-bot

Post an LLM-generated code review to a GitHub PR as **inline comments attributed
to a GitHub App** (a `your-app[bot]` account) rather than the human running the
command.

The agent (Claude) writes the review JSON. The bundled, app-agnostic script
(`skills/post-review-as-bot/scripts/gh-app-review.sh`) does the mechanical work:

- validates every comment against the PR diff and drops unplaceable ones into a
  `⚠️` notice in the review body,
- appends a `Reviewed N comments across Y files` line and an optional footer,
- mints a short-lived installation token from the app's private key,
- submits **one atomic `event: COMMENT` review** (never APPROVE / REQUEST_CHANGES).

## Why a GitHub App?

A normal `gh pr review` posts under *your* user account. To make the review show
up as a distinct bot identity (e.g. so a team can tell automated reviews apart
from human ones), GitHub requires the review to be submitted with an **installation
access token** belonging to a GitHub App. This skill mints that token on the fly
from the app's private key — nothing is stored or long-lived.

## One-time GitHub App setup

You need three values — **App ID**, **Installation ID**, and a **private key
`.pem`** — plus the **Pull requests: Read & write** permission.

### 1. Create the GitHub App

Org-owned (recommended) or personal:

- Org: `https://github.com/organizations/<ORG>/settings/apps/new`
- Personal: **Settings → Developer settings → GitHub Apps → New GitHub App**

Fill in:

- **GitHub App name** — this becomes the `[bot]` name on the review (e.g.
  `my-review-bot` → comments appear as `my-review-bot[bot]`).
- **Homepage URL** — any URL (required by the form).
- **Webhook** — uncheck **Active** (this skill doesn't use webhooks).
- **Permissions → Repository → Pull requests** → **Read & write**.
  (That's the only permission needed.)
- **Where can this app be installed?** — "Only on this account" is fine.

Create the app. On the app's settings page, note the **App ID** (this is your
`GH_APP_ID`).

### 2. Generate a private key

On the app's settings page → **Private keys** → **Generate a private key**. A
`.pem` downloads. Store it somewhere safe and reference it by path, e.g.:

```bash
mkdir -p ~/.config/my-review-bot
mv ~/Downloads/my-review-bot.*.private-key.pem ~/.config/my-review-bot/private-key.pem
chmod 600 ~/.config/my-review-bot/private-key.pem
```

This path is your `GH_APP_PRIVATE_KEY_PATH`.

### 3. Install the app on your org/repo

On the app's settings page → **Install App** → install it on the account/org and
grant it access to the repositories you'll review. After installing, the URL of
the installation settings page ends in a number:

```
https://github.com/organizations/<ORG>/settings/installations/<INSTALLATION_ID>
```

That trailing number is your `GH_APP_INSTALLATION_ID`. (You can also list it via
`gh api /app/installations` once authenticated as the app, or
`gh api /repos/<owner>/<repo>/installation --jq .id`.)

## Environment variables

| Variable                  | Required for      | Value                                            |
| ------------------------- | ----------------- | ------------------------------------------------ |
| `GH_APP_ID`               | live post         | The GitHub App's numeric App ID                  |
| `GH_APP_INSTALLATION_ID`  | live post         | The app's installation ID on the org/repo        |
| `GH_APP_PRIVATE_KEY_PATH` | live post         | Path to the app's `.pem` private key             |
| `GH_APP_REVIEW_FOOTER`    | optional          | Signature appended to the body as `— <footer>`   |

`--dry-run` needs **none** of these — it just prints the exact payload.

## Usage

```bash
# 1. Inspect the payload first (no app identity needed)
echo "$REVIEW_JSON" \
  | bash skills/post-review-as-bot/scripts/gh-app-review.sh post --dry-run

# 2. Post for real, attributed to your-app[bot]
echo "$REVIEW_JSON" \
  | GH_APP_ID=123456 \
    GH_APP_INSTALLATION_ID=87654321 \
    GH_APP_PRIVATE_KEY_PATH=~/.config/my-review-bot/private-key.pem \
    GH_APP_REVIEW_FOOTER='🤖 My Review Bot' \
    bash skills/post-review-as-bot/scripts/gh-app-review.sh post
```

`--pr <num>` and `--repo <owner/name>` auto-detect from the current branch when
omitted. Use `--input <file>` instead of piping if you prefer a file.

## Prerequisites

- `gh` CLI authenticated (`gh auth status`).
- `jq` and `openssl` installed.
- The GitHub App created, installed, and granted **Pull requests: Read & write**.

See `skills/post-review-as-bot/SKILL.md` for the review JSON schema.
