#!/usr/bin/env bash
# Publishes the current PR's AI-generated HTML explainer to the docs-only
# `ai-docs` branch, served via GitHub Pages. The explainer file lives at
# html-explainers/<PR_NUMBER>-<DIFF_ID>-explainer.html.
#
# DIFF_ID is the first 12 chars of `git patch-id --stable` over the PR's net
# diff vs its base branch (origin/main...head). Keying on the DIFF (not the head
# SHA) means a no-op `main` merge — which shifts line numbers but not the PR's
# actual changes — keeps the same DIFF_ID, so a published explainer stays valid.
# `git patch-id --stable` is invariant to @@ line numbers, exactly the property
# we need. The CI check (.github/scripts/pr-explainer-check.sh) computes the same
# id the same way, so publish + check always agree.
#
# Publishing happens inside a THROWAWAY git worktree so the current branch and
# working tree are never touched. The worktree is removed on exit. Each publish
# ALSO syncs the pr-explainer workflow + check script into ai-docs: push events
# run the workflow file FROM the pushed branch (ai-docs), so ai-docs must carry
# the up-to-date copies or the green-on-publish status post silently no-ops.
#
# Usage:
#   pnpm explainer:publish            # derive src from the current PR
#   pnpm explainer:publish path.html  # override the source file path
set -euo pipefail

# --- Locked contract -------------------------------------------------------
# These __TOKEN__ values are filled in at install time by the pr-explainer
# plugin's scripts/install.sh. Re-run the installer to change them.
AI_BRANCH='__AI_BRANCH__'
EXPLAINER_DIR='__EXPLAINER_DIR__'
# Private-repo Pages gets a randomized *.pages.github.io subdomain (org-only).
# Source: gh api repos/:repo/pages --jq .html_url
PAGES_BASE='__PAGES_BASE__'
# CI files mirrored into ai-docs on every publish so the push-triggered run
# there always uses the current gating logic + permissions.
CI_FILES=(
  ".github/workflows/pr-explainer.yml"
  ".github/scripts/pr-explainer-check.sh"
)

# --- 1. Resolve the current branch's PR ------------------------------------
# Pull number, state, head SHA, and base branch as tab-separated values in one
# call so we rely on gh's own JSON parser (jq) rather than string munging.
if ! PR_TSV="$(gh pr view --json number,headRefOid,state,baseRefName \
  --jq '[.number, .state, .headRefOid, .baseRefName] | @tsv' 2>/dev/null)"; then
  echo "No open PR for the current branch" >&2
  exit 1
fi

IFS=$'\t' read -r NUM STATE HEAD_SHA BASE_BRANCH <<<"$PR_TSV"

if [[ "$STATE" != "OPEN" || -z "$NUM" || -z "$HEAD_SHA" ]]; then
  echo "No open PR for the current branch" >&2
  exit 1
fi
BASE_BRANCH="${BASE_BRANCH:-main}"
SHORT="${HEAD_SHA:0:7}"

# --- 2. Compute the diff-stable explainer id -------------------------------
# Make sure both endpoints are present locally, then hash the net diff. Must
# match pr-explainer-check.sh's compute_diff_id() byte-for-byte.
git fetch -q --no-tags origin \
  "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null || true
git fetch -q --no-tags origin "+refs/pull/${NUM}/head:refs/remotes/origin/pr-${NUM}" \
  2>/dev/null || git fetch -q --no-tags origin "$HEAD_SHA" 2>/dev/null || true

# --full-index forces full 40-char blob names on the `index` line. For a
# binary-only diff that line is the only content patch-id hashes, so without it
# a differing core.abbrev would yield a different id here than in CI. Harmless
# for text diffs (patch-id ignores the index line there). Both sides must match.
DIFF_ID="$(git diff --full-index "origin/${BASE_BRANCH}...${HEAD_SHA}" \
  | git patch-id --stable | awk '{print $1}')"
DIFF_ID="${DIFF_ID:0:12}"

if [[ -z "$DIFF_ID" ]]; then
  echo "Could not compute a diff id for PR #${NUM} @ ${SHORT}" >&2
  echo "Ensure origin/${BASE_BRANCH} and the PR head are fetchable, then retry." >&2
  exit 1
fi

# --- 3. Compute the explainer name + source path ---------------------------
NAME="${NUM}-${DIFF_ID}-explainer.html"
SRC="${1:-${EXPLAINER_DIR}/${NAME}}"

# --- 4. Ensure the source file exists --------------------------------------
if [[ ! -f "$SRC" ]]; then
  echo "Explainer not found: ${SRC}" >&2
  echo "Generate it first and write it to ${EXPLAINER_DIR}/${NAME}" >&2
  exit 1
fi

# --- 5. Ensure the ai-docs branch exists -----------------------------------
if ! git fetch origin "$AI_BRANCH" >/dev/null 2>&1; then
  echo "ai-docs branch missing -- bootstrap it first" >&2
  exit 1
fi

# --- 6/7. Publish via a throwaway worktree (cleaned up on exit) -------------
tmp="$(mktemp -d)"

cleanup() {
  if [[ -n "${tmp:-}" ]]; then
    git worktree remove --force "$tmp" >/dev/null 2>&1 || true
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

git worktree add "$tmp" -B "$AI_BRANCH" "origin/${AI_BRANCH}" >/dev/null

mkdir -p "${tmp}/${EXPLAINER_DIR}"
cp "$SRC" "${tmp}/${EXPLAINER_DIR}/${NAME}"
git -C "$tmp" add "${EXPLAINER_DIR}/${NAME}"

# Mirror current CI files into ai-docs (trusted-repo assumption: you publish
# from a branch whose pr-explainer logic is the one you want live).
for f in "${CI_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    mkdir -p "${tmp}/$(dirname "$f")"
    cp "$f" "${tmp}/$f"
    git -C "$tmp" add "$f"
  fi
done

if git -C "$tmp" diff --cached --quiet; then
  echo "already published"
  exit 0
fi

git -C "$tmp" commit -m "docs(explainer): PR #${NUM} @ ${SHORT} (diff ${DIFF_ID})" >/dev/null
git -C "$tmp" push origin "HEAD:${AI_BRANCH}" >/dev/null

# --- 8. Report the rendered Pages URL --------------------------------------
echo "Published explainer for PR #${NUM} @ ${SHORT} (diff ${DIFF_ID})"
echo "${PAGES_BASE}/${EXPLAINER_DIR}/${NAME}"
echo "(GitHub Pages may take ~30-60s to go live.)"
