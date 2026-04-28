#!/usr/bin/env bash
# Usage: notify.sh "Title" "Message"
title="${1:-Ralph}"; msg="${2:-loop ended}"
command -v terminal-notifier >/dev/null && \
  terminal-notifier -title "$title" -message "$msg" -sound default
printf '\a' >&2
