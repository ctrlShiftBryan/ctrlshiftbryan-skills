#!/usr/bin/env bash
# gh-app-review — post a pre-made LLM code review to a GitHub PR as ANY GitHub
# App (inline comments, Copilot-style). App-agnostic: identity comes from env.
#
# The review is produced upstream by *some* LLM (Claude Code, Codex, …). This
# script never reasons about code: it validates each comment against the PR diff,
# drops unplaceable ones into a notice in the body, and submits ONE atomic
# `event: COMMENT` review minted under the app's installation token so the
# comments are attributed to the app rather than the human who ran it.
#
# Input (stdin or --input): { "summary": "...", "comments": [ {path,line,...,body} ] }
# See skills/post-review-as-bot/SKILL.md for the full schema.
#
# Functions are prefixed `ar_` and the file is source-guarded at the bottom so a
# test harness can source it and exercise the pure units (parser/partition/body/
# jwt) without running main.

# ---- env contract (live post only; --dry-run needs none of these) ------------
# GH_APP_ID                  — the GitHub App's id
# GH_APP_INSTALLATION_ID     — the app's installation id on the target org/repo
# GH_APP_PRIVATE_KEY_PATH    — path to the app's .pem
# GH_APP_REVIEW_FOOTER       — optional signature appended as "— <footer>"

# ---- diff hunk parser -------------------------------------------------------
# stdin: a single file's unified-diff `patch` (the GitHub files-API field, which
# starts at the first `@@`). stdout: one `side<TAB>line<TAB>hunk` row per
# commentable position. RIGHT lines = added + context (new-file numbering);
# LEFT lines = deleted + context (old-file numbering). `hunk` is a 1-based index
# so ranged comments can require both endpoints in the same hunk.
ar_targets_from_patch() {
  awk '
    BEGIN { hunk = 0 }
    /^@@/ {
      hunk++
      os = $2; sub(/^-/, "", os); split(os, oa, ","); oldline = oa[1] + 0
      ns = $3; sub(/^\+/, "", ns); split(ns, na, ","); newline = na[1] + 0
      next
    }
    {
      if (hunk == 0) next
      c = substr($0, 1, 1)
      if (c == "+") { print "RIGHT\t" newline "\t" hunk; newline++ }
      else if (c == "-") { print "LEFT\t" oldline "\t" hunk; oldline++ }
      else if (c == " ") {
        print "RIGHT\t" newline "\t" hunk
        print "LEFT\t" oldline "\t" hunk
        newline++; oldline++
      }
    }
  '
}

# stdin: `path<TAB>side<TAB>line<TAB>hunk` rows. stdout: JSON object mapping
# "path|side|line" -> hunk index, used as the valid-target lookup.
ar_build_valid_json() {
  jq -R -s '
    [ split("\n")[] | select(length > 0) | split("\t")
      | { key: "\(.[0])|\(.[1])|\(.[2])", value: (.[3] | tonumber) } ]
    | from_entries
  '
}

# args: <valid-json-file> <input-json-file> <unavailable-paths-json-file>.
# stdout: { placeable: [...], dropped: [...], unavailable: [...] }. Bulk JSON
# stays in files so large diffs cannot exceed the process argument-size limit.
# A comment is placeable iff its end (path,side,line) is a valid target, and —
# when ranged — its start is valid, in the SAME hunk, and start_line <= line.
# A non-placeable comment is unavailable when GitHub omitted that file's patch;
# every other non-placeable comment is dropped as an invalid diff anchor.
ar_partition() {
  local valid_file="$1" input_file="$2" unavailable_file="$3"
  jq -n \
    --slurpfile valid "$valid_file" \
    --slurpfile input "$input_file" \
    --slurpfile unavailable "$unavailable_file" '
    ($valid[0] // {}) as $targets
    | ($input[0] // {}) as $review
    | ($unavailable[0] // []) as $unavailable_paths
    |
    def eside(c): (c.side // "RIGHT");
    def sside(c): (c.start_side // c.side // "RIGHT");
    def endkey(c):   "\(c.path)|\(eside(c))|\(c.line)";
    def startkey(c): "\(c.path)|\(sside(c))|\(c.start_line)";
    def placeable(c):
      c as $comment
      | ($targets[endkey($comment)] != null)
      and ( if ($comment.start_line != null)
            then ($targets[startkey($comment)] != null)
                 and ($targets[startkey($comment)] == $targets[endkey($comment)])
                 and ($comment.start_line <= $comment.line)
            else true end );
    def patch_unavailable(c):
      c as $comment | ($unavailable_paths | index($comment.path)) != null;
    ($review.comments // []) as $cs
    | { placeable: [ $cs[] | select(placeable(.)) ],
        dropped: [ $cs[] | select((placeable(.) or patch_unavailable(.)) | not) ],
        unavailable: [ $cs[] | select((placeable(.) | not) and patch_unavailable(.)) ] }
  '
}

# stdin: placeable array. stdout: GitHub reviews-API `comments` array (only the
# API fields; start_* included only for a genuine multi-line range).
ar_review_comments() {
  jq '[ .[] | {
          path: .path,
          body: .body,
          line: .line,
          side: (.side // "RIGHT")
        }
        + ( if (.start_line != null and .start_line < .line)
            then { start_line: .start_line, start_side: (.start_side // .side // "RIGHT") }
            else {} end )
      ]'
}

# args: <summary-file> <n-comments> <y-files> <dropped-json-file>
# <unavailable-json-file> [footer]. stdout: review body. Always emits the
# mechanical line; appends distinct notices for invalid anchors and unavailable
# GitHub patches, plus a "— <footer>" signature when a footer is given.
ar_compose_body() {
  local summary_file="$1" n="$2" y="$3" dropped_file="$4" unavailable_file="$5" footer="${6:-}"
  jq -n -rj \
    --rawfile summary "$summary_file" \
    --argjson n "$n" \
    --argjson y "$y" \
    --slurpfile dropped "$dropped_file" \
    --slurpfile unavailable "$unavailable_file" \
    --arg footer "$footer" '
    ($dropped[0] // []) as $invalid_comments
    | ($unavailable[0] // []) as $unavailable_comments
    | ( if ($summary | length) > 0 then $summary + "\n\n" else "" end )
    + "---\n"
    + "Reviewed \($n) comment\(if $n == 1 then "" else "s" end) across \($y) file\(if $y == 1 then "" else "s" end)."
    + ( if ($invalid_comments | length) > 0 then
          "\n\n**⚠️ Comments that could not be placed inline** (line not in the diff):\n\n"
          + ( [ $invalid_comments[] | "- `\(.path):\(.line)` — " + ((.body // "") | gsub("\n"; " ")) ] | join("\n") )
        else "" end )
    + ( if ($unavailable_comments | length) > 0 then
          "\n\n**⚠️ Comments that could not be validated inline** (GitHub did not provide patch data for the file):\n\n"
          + ( [ $unavailable_comments[] | "- `\(.path):\(.line)` — " + ((.body // "") | gsub("\n"; " ")) ] | join("\n") )
        else "" end )
    + ( if ($footer | length) > 0 then "\n\n— " + $footer else "" end )
  '
}

# ---- token minting ----------------------------------------------------------
ar_b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# args: <pem> <app_id>. stdout: a signed RS256 JWT (≤10 min). No network.
ar_make_jwt() {
  local pem="$1" app_id="$2" now iat exp header payload signing_input sig
  now="$(date +%s)"; iat="$((now - 60))"; exp="$((now + 540))"
  header='{"alg":"RS256","typ":"JWT"}'
  if [[ "$app_id" =~ ^[0-9]+$ ]]; then
    payload="$(printf '{"iat":%d,"exp":%d,"iss":%d}' "$iat" "$exp" "$app_id")"
  else
    payload="$(jq -nc --argjson iat "$iat" --argjson exp "$exp" --arg iss "$app_id" '{iat:$iat,exp:$exp,iss:$iss}')"
  fi
  signing_input="$(printf '%s' "$header" | ar_b64url).$(printf '%s' "$payload" | ar_b64url)"
  sig="$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$pem" -binary | ar_b64url)"
  printf '%s.%s' "$signing_input" "$sig"
}

# args: <pem> <app_id> <installation_id>. stdout: a ≤1h installation token.
ar_mint_token() {
  local pem="$1" app_id="$2" inst="$3" jwt
  jwt="$(ar_make_jwt "$pem" "$app_id")"
  # shellcheck disable=SC1007  # clear GH_TOKEN for this call so the Bearer JWT is used
  GH_TOKEN= gh api -X POST "/app/installations/${inst}/access_tokens" \
    -H "Authorization: Bearer ${jwt}" --jq .token
}

# ---- main -------------------------------------------------------------------
ar_die() { printf 'gh-app-review: %s\n' "$1" >&2; exit 1; }

ar_usage() {
  cat <<'EOF'
gh-app-review post [--pr <num>] [--repo <owner/name>] [--input <file>] [--dry-run]

Posts a pre-made review (JSON on stdin or --input) to a GitHub PR as a GitHub
App. --pr/--repo auto-detect from the current branch when omitted. --dry-run
prints the exact payload and posts nothing.

Env (live post): GH_APP_ID, GH_APP_INSTALLATION_ID, GH_APP_PRIVATE_KEY_PATH.
Optional: GH_APP_REVIEW_FOOTER (signature line).
EOF
}

ar_main() {
  set -euo pipefail

  local sub="${1:-}"; shift || true
  case "$sub" in
    post) ;;
    ""|-h|--help|help) ar_usage; exit 0 ;;
    *) ar_usage >&2; ar_die "unknown command '$sub'" ;;
  esac

  local pr="" repo="" input_file="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pr)     pr="${2:?--pr needs a value}"; shift 2 ;;
      --repo)   repo="${2:?--repo needs a value}"; shift 2 ;;
      --input)  input_file="${2:?--input needs a value}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      -h|--help) ar_usage; exit 0 ;;
      *) ar_die "unknown flag '$1'" ;;
    esac
  done

  command -v gh >/dev/null 2>&1 || ar_die "gh CLI not found"
  command -v jq >/dev/null 2>&1 || ar_die "jq not found"

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand the validated mktemp path while the local is in scope
  trap "rm -rf -- '$tmpdir'" EXIT

  # read and validate review JSON
  local review_input
  if [[ -n "$input_file" ]]; then
    [[ -f "$input_file" ]] || ar_die "input file not found: $input_file"
    review_input="$input_file"
    jq -e . "$review_input" >/dev/null 2>&1 || ar_die "input is not valid JSON"
  else
    review_input="${tmpdir}/input.json"
    jq -e . >"$review_input" 2>/dev/null || ar_die "input is not valid JSON"
  fi

  # resolve repo / pr / head sha
  [[ -n "$repo" ]] || repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
    || ar_die "could not resolve repo (pass --repo)"
  if [[ -z "$pr" ]]; then
    pr="$(gh pr view --repo "$repo" --json number -q .number)" \
      || ar_die "could not resolve PR from current branch (pass --pr)"
  fi
  local head_sha
  head_sha="$(gh pr view "$pr" --repo "$repo" --json headRefOid -q .headRefOid)" \
    || ar_die "could not read head SHA for PR #$pr"

  # build the valid-target set from the PR diff
  local files_json="${tmpdir}/files.json" y targets="${tmpdir}/targets.tsv"
  local unavailable_paths="${tmpdir}/unavailable-paths.json"
  gh api --paginate "/repos/${repo}/pulls/${pr}/files" | jq -s 'add // []' >"$files_json"
  y="$(jq 'length' "$files_json")"
  jq '[ .[] | select(.patch == null) | .filename ]' "$files_json" >"$unavailable_paths"
  while IFS= read -r row; do
    local path patch
    path="$(jq -r '.filename' <<<"$row")"
    patch="$(jq -r '.patch // empty' <<<"$row")"
    [[ -n "$patch" ]] || continue
    printf '%s\n' "$patch" | ar_targets_from_patch \
      | awk -v p="$path" 'BEGIN{FS=OFS="\t"} {print p,$1,$2,$3}'
  done < <(jq -c '.[]' "$files_json") >"$targets"

  local valid_json="${tmpdir}/valid.json" part="${tmpdir}/partition.json"
  local placeable="${tmpdir}/placeable.json" dropped="${tmpdir}/dropped.json"
  local unavailable_comments="${tmpdir}/unavailable-comments.json"
  local comments_payload="${tmpdir}/comments.json" summary="${tmpdir}/summary.txt"
  local body="${tmpdir}/body.txt" payload="${tmpdir}/payload.json" n
  ar_build_valid_json <"$targets" >"$valid_json"
  ar_partition "$valid_json" "$review_input" "$unavailable_paths" >"$part"
  jq '.placeable' "$part" >"$placeable"
  jq '.dropped' "$part" >"$dropped"
  jq '.unavailable' "$part" >"$unavailable_comments"
  n="$(jq 'length' "$placeable")"
  ar_review_comments <"$placeable" >"$comments_payload"
  jq -rj '.summary // ""' "$review_input" >"$summary"
  ar_compose_body \
    "$summary" \
    "$n" \
    "$y" \
    "$dropped" \
    "$unavailable_comments" \
    "${GH_APP_REVIEW_FOOTER:-}" >"$body"
  jq -n \
    --arg commit "$head_sha" \
    --rawfile body "$body" \
    --slurpfile comments "$comments_payload" \
    '{ commit_id: $commit, event: "COMMENT", body: $body, comments: ($comments[0] // []) }' \
    >"$payload"

  if [[ "$dry_run" -eq 1 ]]; then
    printf '=== DRY RUN — repo=%s pr=#%s head=%s ===\n' "$repo" "$pr" "$head_sha" >&2
    printf 'placeable=%s dropped=%s unavailable=%s files=%s\n' \
      "$n" \
      "$(jq 'length' "$dropped")" \
      "$(jq 'length' "$unavailable_comments")" \
      "$y" >&2
    jq . "$payload"
    return 0
  fi

  # live post — mint the installation token only for this call
  local app_id="${GH_APP_ID:-}" inst_id="${GH_APP_INSTALLATION_ID:-}" pem="${GH_APP_PRIVATE_KEY_PATH:-}"
  [[ -n "$app_id" ]] || ar_die "GH_APP_ID is unset (use --dry-run otherwise)"
  [[ -n "$inst_id" ]] || ar_die "GH_APP_INSTALLATION_ID is unset (use --dry-run otherwise)"
  [[ -n "$pem" ]] || ar_die "GH_APP_PRIVATE_KEY_PATH is unset (need the app .pem to post; use --dry-run otherwise)"
  [[ -f "$pem" ]] || ar_die "private key not found at: $pem"
  local token url
  token="$(ar_mint_token "$pem" "$app_id" "$inst_id")" \
    || ar_die "failed to mint installation token"
  url="$(GH_TOKEN="$token" gh api -X POST \
    "/repos/${repo}/pulls/${pr}/reviews" --input "$payload" --jq '.html_url')" \
    || ar_die "review POST failed"
  printf 'Posted review as the GitHub App: %s\n' "$url"
}

# Run main only when executed directly; sourcing exposes the ar_* units for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ar_main "$@"
fi
