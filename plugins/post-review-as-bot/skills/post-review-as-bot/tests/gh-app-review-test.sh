#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/../scripts" && pwd)"
# The runtime-resolved path keeps the test portable across installation roots.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/gh-app-review.sh"

test_tmp="$(mktemp -d)"
trap 'rm -rf -- "$test_tmp"' EXIT

assert_jq() {
  local file="$1" expression="$2" message="$3"
  if ! jq -e "$expression" "$file" >/dev/null; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

printf '%s\n' '{"src/example.ts|RIGHT|10":1}' >"${test_tmp}/valid.json"
printf '%s\n' '[]' >"${test_tmp}/unavailable.json"
cat >"${test_tmp}/input.json" <<'JSON'
{
  "summary": "Review summary",
  "comments": [
    {"path":"src/example.ts","line":10,"body":"Place me"},
    {"path":"src/example.ts","line":99,"body":"Drop me"}
  ]
}
JSON

ar_partition \
  "${test_tmp}/valid.json" \
  "${test_tmp}/input.json" \
  "${test_tmp}/unavailable.json" >"${test_tmp}/partition.json"

assert_jq "${test_tmp}/partition.json" '.placeable | length == 1' \
  'valid comments should remain placeable'
assert_jq "${test_tmp}/partition.json" '.dropped | length == 1' \
  'invalid anchors should be dropped'
assert_jq "${test_tmp}/partition.json" '.unavailable | length == 0' \
  'available patches should not be classified as unavailable'

printf '%s\n' '["fixtures/large.xml"]' >"${test_tmp}/unavailable.json"
cat >"${test_tmp}/input.json" <<'JSON'
{
  "comments": [
    {"path":"fixtures/large.xml","line":1,"body":"Patch unavailable"},
    {"path":"src/example.ts","line":99,"body":"Anchor invalid"}
  ]
}
JSON

ar_partition \
  "${test_tmp}/valid.json" \
  "${test_tmp}/input.json" \
  "${test_tmp}/unavailable.json" >"${test_tmp}/partition.json"

assert_jq "${test_tmp}/partition.json" '.unavailable | length == 1' \
  'comments on omitted patches should have their own classification'
assert_jq "${test_tmp}/partition.json" '.dropped | length == 1' \
  'invalid anchors on available patches should remain dropped'

long_path='src/this/is/a/deliberately/long/path/used/to/build/a/large/anchor-map/example.ts'
awk -v path="$long_path" 'BEGIN {
  for (line = 1; line <= 50000; line++) {
    print path "\tRIGHT\t" line "\t1"
  }
}' >"${test_tmp}/large-targets.tsv"
ar_build_valid_json <"${test_tmp}/large-targets.tsv" >"${test_tmp}/large-valid.json"

arg_max="$(getconf ARG_MAX)"
valid_bytes="$(wc -c <"${test_tmp}/large-valid.json" | tr -d ' ')"
if (( valid_bytes <= arg_max )); then
  printf 'FAIL: large-map fixture (%s bytes) must exceed ARG_MAX (%s bytes)\n' \
    "$valid_bytes" "$arg_max" >&2
  exit 1
fi

printf '%s\n' '[]' >"${test_tmp}/unavailable.json"
jq -n --arg path "$long_path" \
  '{comments:[{path:$path,line:50000,body:"Last anchor"}]}' \
  >"${test_tmp}/input.json"

ar_partition \
  "${test_tmp}/large-valid.json" \
  "${test_tmp}/input.json" \
  "${test_tmp}/unavailable.json" >"${test_tmp}/partition.json"

assert_jq "${test_tmp}/partition.json" '.placeable | length == 1' \
  'partitioning should keep bulk anchor data off the process argument list'

printf 'Review summary' >"${test_tmp}/summary.txt"
printf '%s\n' '[{"path":"src/example.ts","line":99,"body":"Anchor invalid"}]' \
  >"${test_tmp}/dropped.json"
printf '%s\n' '[{"path":"fixtures/large.xml","line":1,"body":"Patch unavailable"}]' \
  >"${test_tmp}/unavailable-comments.json"

ar_compose_body \
  "${test_tmp}/summary.txt" \
  1 \
  2 \
  "${test_tmp}/dropped.json" \
  "${test_tmp}/unavailable-comments.json" \
  '' >"${test_tmp}/body.txt"

grep -q 'line not in the diff' "${test_tmp}/body.txt" \
  || { printf 'FAIL: body should explain invalid anchors\n' >&2; exit 1; }
grep -q 'GitHub did not provide patch data' "${test_tmp}/body.txt" \
  || { printf 'FAIL: body should explain unavailable patches\n' >&2; exit 1; }

printf 'PASS: gh-app-review regressions\n'
