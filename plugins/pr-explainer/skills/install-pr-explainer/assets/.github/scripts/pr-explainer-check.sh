#!/usr/bin/env bash
# Posts (or updates) a sticky PR comment nagging for an AI-generated HTML
# "explainer" and links the published copy once it exists. The HTML marker
# identifies the comment so re-runs replace rather than append.
#
# Three freshness states keyed on the PR's net-diff identity (DIFF_ID), NOT the
# head commit SHA. DIFF_ID = first 12 chars of `git patch-id --stable` over
# origin/<base>...<head>. patch-id is invariant to @@ line-number shifts, so
# merging the base branch in (which moves the head SHA but not the PR's actual
# changes) yields the SAME DIFF_ID and a published explainer stays GREEN.
#   GREEN  explainer exists for the current DIFF_ID
#   YELLOW only an explainer for an older DIFF_ID of this PR exists
#   RED    no explainer exists for this PR
#
# Each state upserts a sticky comment AND posts a `pr-explainer` commit status
# to the PR head SHA: success for GREEN, failure for YELLOW/RED. The commit
# status (not the job exit code) is the gating check on the PR -- because it is
# keyed on the head SHA, the push-to-ai-docs run that fires after `explainer:
# publish` re-posts success on that same SHA and flips the check green with no
# new commit. The job itself always exits 0.
#
# Driven by the GitHub Actions event:
#   pull_request : evaluate the single PR from the event payload
#   push         : (on ai-docs) evaluate every OPEN PR whose explainer file
#                  was added/modified in the push
#
# Required env (passed by the workflow):
#   GH_TOKEN       token with pull-requests: write
#   GH_REPO        owner/repo (e.g. ${{ github.repository }})
#   AI_BRANCH      orphan docs branch holding explainers (ai-docs)
#   EXPLAINER_DIR  folder on AI_BRANCH (html-explainers)
#   PAGES_BASE     GitHub Pages base URL
# Auto-provided by Actions:
#   GITHUB_EVENT_NAME, GITHUB_EVENT_PATH
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GH_REPO:?GH_REPO is required}"
: "${AI_BRANCH:?AI_BRANCH is required}"
: "${EXPLAINER_DIR:?EXPLAINER_DIR is required}"
: "${PAGES_BASE:?PAGES_BASE is required}"
: "${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME is required}"
: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH is required}"

MARKER='<!-- pr-explainer-bot -->'

# Commit-status context = the check name shown on the PR. Keep it stable so the
# pull_request run and the push-to-ai-docs run write to the same check.
STATUS_CONTEXT='pr-explainer'

# Worst state seen across evaluated PRs (green < yellow < red). Drives the final
# log line only; the gating signal is the per-SHA commit status, not exit code.
WORST_STATE='green'

# Set to 1 if any commit-status POST fails. The commit status IS the gate, so a
# failed POST leaves the PR silently ungated. We fail the job closed at the end
# in that case. This is distinct from the green/yellow/red flow (which always
# exits 0 so the push-to-ai-docs run can re-green the same SHA) -- a POST failure
# is a broken-gate infra error, not a stale-explainer state.
STATUS_POST_FAILED=0

# Escalate WORST_STATE. $1 = this PR's state (green|yellow|red).
note_state() {
  case "$1" in
    red) WORST_STATE='red' ;;
    yellow) [[ "$WORST_STATE" == 'red' ]] || WORST_STATE='yellow' ;;
  esac
}

# Post a `pr-explainer` commit status to a head SHA.
#   $1 = full head SHA   $2 = state (success|failure)
#   $3 = description (<=140 chars)   $4 = target_url (optional)
post_status() {
  local sha="$1" state="$2" description="$3" target_url="${4:-}" ok=1
  if [[ -n "$target_url" ]]; then
    gh api -X POST "repos/${GH_REPO}/statuses/${sha}" \
      -f state="$state" -f context="$STATUS_CONTEXT" \
      -f description="$description" -f target_url="$target_url" >/dev/null || ok=0
  else
    gh api -X POST "repos/${GH_REPO}/statuses/${sha}" \
      -f state="$state" -f context="$STATUS_CONTEXT" \
      -f description="$description" >/dev/null || ok=0
  fi
  if [[ "$ok" -eq 0 ]]; then
    echo "::warning::Failed to post '${state}' ${STATUS_CONTEXT} status for ${sha}"
    STATUS_POST_FAILED=1
  fi
}

# Stable identity of a PR's net diff vs its base branch. Uses `git patch-id
# --stable`, which is invariant to @@ line-number shifts, so merging the base
# branch in (a no-op for the PR's actual changes) yields the SAME id and the
# already-published explainer stays valid. MUST mirror explainer-publish.sh's
# computation byte-for-byte so publish + check always agree on the filename.
#   $1 = PR number   $2 = head SHA (full)   echoes a 12-char hex id (or "")
compute_diff_id() {
  local pr_number="$1" head_sha="$2" base="${BASE_BRANCH:-main}" id
  git fetch -q --no-tags origin \
    "+refs/heads/${base}:refs/remotes/origin/${base}" 2>/dev/null || true
  git fetch -q --no-tags origin \
    "+refs/pull/${pr_number}/head:refs/remotes/origin/pr-${pr_number}" 2>/dev/null \
    || git fetch -q --no-tags origin "$head_sha" 2>/dev/null || true
  # --full-index keeps the id stable across core.abbrev configs (full blob
  # names on the `index` line); MUST mirror explainer-publish.sh exactly.
  id="$(git diff --full-index "origin/${base}...${head_sha}" 2>/dev/null \
    | git patch-id --stable 2>/dev/null | awk '{print $1}')"
  printf '%s' "${id:0:12}"
}

# The generation prompt lives in its own file (single source of truth, embedded
# verbatim into the bot comment). It carries install-time tokens (__PUBLISH_CMD__)
# plus runtime placeholders ({{EXPLAINER_PATH}}, {{PR_URL}}) filled per PR below.
# Resolved relative to THIS script so it works regardless of the caller's cwd.
PROMPT_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../prompts/explainer-generation.md"

# Build the verbatim Claude Code generation prompt for a concrete filename.
# $1 = explainer filename (e.g. 101-bff96aa-explainer.html)   $2 = PR number
generation_prompt() {
  local filename="$1" pr_number="$2"
  local pr_url="https://github.com/${GH_REPO}/pull/${pr_number}"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    # Mirror lag / missing file: degrade to a minimal inline ask so the bot
    # comment still tells the user what to do. ('#' is safe as the sed delim:
    # neither the path nor the URL can contain it.)
    echo "::warning::prompt file not found at ${PROMPT_FILE}; using inline fallback" >&2
    printf '/zoom-out and explain what this PR does, then build an html explainer and write it to %s\n\nLink back to the PR: %s\n' \
      "${EXPLAINER_DIR}/${filename}" "$pr_url"
    return
  fi
  sed -e "s#{{EXPLAINER_PATH}}#${EXPLAINER_DIR}/${filename}#g" \
      -e "s#{{PR_URL}}#${pr_url}#g" \
      "$PROMPT_FILE"
}

# Upsert the sticky comment for a PR. $1 = PR number, $2 = comment body.
upsert_comment() {
  local pr_number="$1"
  local body="$2"
  local existing_id

  existing_id="$(gh api "repos/${GH_REPO}/issues/${pr_number}/comments" \
    --paginate \
    --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" \
    | head -n1)"

  if [[ -n "$existing_id" ]]; then
    echo "PR #${pr_number}: updating existing sticky comment ${existing_id}"
    gh api -X PATCH "repos/${GH_REPO}/issues/comments/${existing_id}" \
      -f body="$body" >/dev/null
  else
    echo "PR #${pr_number}: posting new sticky comment"
    gh api -X POST "repos/${GH_REPO}/issues/${pr_number}/comments" \
      -f body="$body" >/dev/null
  fi
}

# Evaluate one PR and upsert its sticky comment.
# $1 = PR number, $2 = head SHA (full).
evaluate_pr() {
  local pr_number="$1"
  local head_sha="$2"
  local head_short="${head_sha:0:7}"

  # Key on the net-diff identity so a no-op base-branch merge doesn't go stale.
  local diff_id
  diff_id="$(compute_diff_id "$pr_number" "$head_sha")"
  if [[ -z "$diff_id" ]]; then
    echo "::warning::Could not compute diff id for PR #${pr_number} @ ${head_short}"
    post_status "$head_sha" "failure" \
      "Could not compute diff id for ${head_short} -- see workflow logs"
    note_state red
    return
  fi
  local head_file="${pr_number}-${diff_id}-explainer.html"

  # List explainer filenames on AI_BRANCH. 404 (folder absent) -> empty.
  local names
  names="$(gh api "repos/${GH_REPO}/contents/${EXPLAINER_DIR}?ref=${AI_BRANCH}" \
    --jq '.[].name' 2>/dev/null || true)"

  local rendered_head="${PAGES_BASE}/${EXPLAINER_DIR}/${head_file}"
  local source_head="https://github.com/${GH_REPO}/blob/${AI_BRANCH}/${EXPLAINER_DIR}/${head_file}"
  local body

  if printf '%s\n' "$names" | grep -qxF "$head_file"; then
    # GREEN
    body="$(cat <<EOF
${MARKER}
## 🟢 PR Explainer ready

Explainer for commit \`${head_short}\`: **[Open explainer](${rendered_head})** ([source](${source_head}))

_Pages may take ~30-60s to go live after publishing._
EOF
)"
    upsert_comment "$pr_number" "$body"
    post_status "$head_sha" "success" \
      "Explainer ready for ${head_short}" "$rendered_head"
    note_state green
    return
  fi

  # Find older candidates for this PR: ^<PR#>-<diffid>-explainer\.html$
  # ({7,40} keeps legacy 7-char short-SHA names matchable alongside 12-char ids.)
  local candidates
  candidates="$(printf '%s\n' "$names" \
    | grep -E "^${pr_number}-[0-9a-f]{7,40}-explainer\.html$" || true)"

  if [[ -n "$candidates" ]]; then
    # YELLOW: pick the most recently committed older candidate.
    local best_file="" best_date="" candidate date
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      date="$(gh api \
        "repos/${GH_REPO}/commits?sha=${AI_BRANCH}&path=${EXPLAINER_DIR}/${candidate}&per_page=1" \
        --jq '.[0].commit.committer.date' 2>/dev/null || true)"
      if [[ -z "$best_date" || "$date" > "$best_date" ]]; then
        best_date="$date"
        best_file="$candidate"
      fi
    done <<<"$candidates"

    # Fall back to the last sorted candidate if dates were unavailable.
    if [[ -z "$best_file" ]]; then
      best_file="$(printf '%s\n' "$candidates" | tail -n1)"
    fi

    local old_id="${best_file#"${pr_number}-"}"
    old_id="${old_id%%-explainer.html}"
    local rendered_old="${PAGES_BASE}/${EXPLAINER_DIR}/${best_file}"

    body="$(cat <<EOF
${MARKER}
## 🟡 PR Explainer is stale

An explainer exists for an older version of this PR's diff (\`${old_id}\`) but the
current diff is \`${diff_id}\` (head \`${head_short}\`). The PR's actual changes
moved -- a no-op base-branch merge alone would NOT trigger this.

[View the stale explainer](${rendered_old})

Regenerate and publish it for the current diff -- run this prompt in Claude Code:

\`\`\`
$(generation_prompt "$head_file" "$pr_number")
\`\`\`

This check turns green automatically once the explainer is published to the ${AI_BRANCH} branch.
EOF
)"
    upsert_comment "$pr_number" "$body"
    post_status "$head_sha" "failure" \
      "Stale: explainer diff is ${old_id}, current is ${diff_id}" "$rendered_old"
    note_state yellow
    return
  fi

  # RED: no explainer for this PR at all.
  body="$(cat <<EOF
${MARKER}
## 🔴 PR Explainer needed

No explainer found for the current commit \`${head_short}\`.

Generate and publish it -- run this prompt in Claude Code:

\`\`\`
$(generation_prompt "$head_file" "$pr_number")
\`\`\`

This check turns green automatically once the explainer is published to the ${AI_BRANCH} branch.
EOF
)"
  upsert_comment "$pr_number" "$body"
  post_status "$head_sha" "failure" "No explainer for ${head_short} -- generate & publish"
  note_state red
}

# Build the (PR_NUMBER, HEAD_SHA) work list and evaluate each.
if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
  pr_number="$(jq -r '.pull_request.number' "$GITHUB_EVENT_PATH")"
  head_sha="$(jq -r '.pull_request.head.sha' "$GITHUB_EVENT_PATH")"
  if [[ -z "$pr_number" || "$pr_number" == "null" \
    || -z "$head_sha" || "$head_sha" == "null" ]]; then
    echo "::error::Could not read PR number/head SHA from event payload" >&2
    exit 1
  fi
  evaluate_pr "$pr_number" "$head_sha"

elif [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
  # Determine which explainer files changed. The push payload's per-commit
  # added/modified arrays are unreliable in the Actions push event, so use the
  # compare API (authoritative) between the before/after SHAs. Fall back to every
  # explainer currently on AI_BRANCH when before is empty (branch creation) or
  # the compare lookup fails.
  before_sha="$(jq -r '.before // ""' "$GITHUB_EVENT_PATH")"
  after_sha="$(jq -r '.after // ""' "$GITHUB_EVENT_PATH")"

  changed=""
  if [[ -n "$before_sha" \
    && "$before_sha" != "0000000000000000000000000000000000000000" \
    && -n "$after_sha" ]]; then
    changed="$(gh api "repos/${GH_REPO}/compare/${before_sha}...${after_sha}" \
      --jq '.files[].filename' 2>/dev/null || true)"
  fi

  if [[ -z "$changed" ]]; then
    changed="$(gh api "repos/${GH_REPO}/contents/${EXPLAINER_DIR}?ref=${AI_BRANCH}" \
      --jq '.[].name' 2>/dev/null | sed "s#^#${EXPLAINER_DIR}/#" || true)"
  fi

  pr_numbers="$(printf '%s\n' "$changed" \
    | grep -E "^${EXPLAINER_DIR}/[0-9]+-[0-9a-f]{7,40}-explainer\.html$" \
    | sed -E "s#^${EXPLAINER_DIR}/([0-9]+)-.*#\1#" \
    | sort -u || true)"

  if [[ -z "$pr_numbers" ]]; then
    echo "No explainer files changed in this push; nothing to do."
    exit 0
  fi

  while IFS= read -r pr_number; do
    [[ -n "$pr_number" ]] || continue
    pr_json="$(gh pr view "$pr_number" --repo "$GH_REPO" \
      --json number,state,headRefOid 2>/dev/null || true)"
    if [[ -z "$pr_json" ]]; then
      echo "PR #${pr_number}: could not be fetched; skipping."
      continue
    fi
    state="$(jq -r '.state' <<<"$pr_json")"
    if [[ "$state" != "OPEN" ]]; then
      echo "PR #${pr_number}: state ${state}; skipping (only OPEN PRs)."
      continue
    fi
    head_sha="$(jq -r '.headRefOid' <<<"$pr_json")"
    evaluate_pr "$pr_number" "$head_sha"
  done <<<"$pr_numbers"

else
  echo "::error::Unsupported event '${GITHUB_EVENT_NAME}'" >&2
  exit 1
fi

if [[ "$WORST_STATE" == 'green' ]]; then
  echo "Done. All evaluated explainers are green."
else
  # Gating happens via the per-SHA commit status posted above, not this exit
  # code -- a non-zero job here would create a workflow check that cannot be
  # flipped green by the push-to-ai-docs run on the same commit.
  echo "Done. Worst explainer status: ${WORST_STATE}. A failing '${STATUS_CONTEXT}' commit status is on the PR; publish the explainer to turn it green."
fi

# Fail closed: if we could not post the commit status that IS the gate, the PR
# is silently ungated. Surface that as a red workflow check. Unlike the
# green/yellow/red flow above, this is a broken-gate infra error, so failing the
# job is correct -- a later successful run re-posts the status and clears it.
if [[ "$STATUS_POST_FAILED" -eq 1 ]]; then
  echo "::error::Failed to post the '${STATUS_CONTEXT}' commit status; failing closed so the missing gate is visible." >&2
  exit 1
fi
