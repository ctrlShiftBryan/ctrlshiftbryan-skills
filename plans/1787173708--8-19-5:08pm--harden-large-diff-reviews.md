# Harden Large-Diff Bot Reviews

## Context and assumptions

- `post-review-as-bot` currently passes the complete valid-anchor map to `jq` through process arguments, so sufficiently large pull-request diffs exceed the operating system's argument-size limit.
- GitHub's pull-request files response can omit a file's `patch`. An omitted patch is different from an invalid line anchor and should be reported explicitly.
- The review-posting API contract and atomic `COMMENT` review behavior should remain unchanged.

## Implementation phases

1. Add a regression harness covering oversized anchor data and files whose patch is unavailable.
2. Move bulk JSON exchange from command-line arguments to files or standard input while preserving the existing partition behavior.
3. Track unavailable-patch paths during validation and classify affected comments separately in the composed review body.
4. Update the skill documentation to describe the classifications and large-diff-safe behavior.
5. Run focused regressions, shell syntax checks, and plugin discovery verification.

## Expected outcomes

- Dry runs and live reviews do not fail merely because the valid-anchor map exceeds `ARG_MAX`.
- Comments targeting unavailable patches are retained in a clearly labeled review-body notice rather than mislabeled as lines outside the diff.
- Placeable inline comments and genuinely invalid anchors keep their existing behavior.
