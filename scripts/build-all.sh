#!/usr/bin/env bash
# build-all.sh — read feeds.txt and build an Atom feed for each entry, plus index.html.
#
# Usage:
#   build-all.sh <site-dir> <feeds-file> <base-url>

set -euo pipefail

SITE="${1:?usage: $0 <site-dir> <feeds-file> <base-url>}"
FEEDS="${2:?usage: $0 <site-dir> <feeds-file> <base-url>}"
BASE_URL="${3:?usage: $0 <site-dir> <feeds-file> <base-url>}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SITE"

failed=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -z "$line" ]] && continue

  repo="$line"
  slug="${repo/\//--}"
  out="${SITE}/${slug}.atom"
  feed_url="${BASE_URL%/}/${slug}.atom"

  echo "::group::Building feed for ${repo}"
  if ! "${here}/ghsa-to-atom.sh" "$repo" "$out" "$feed_url"; then
    echo "::error::failed to build feed for ${repo}"
    failed=$((failed + 1))
  fi
  echo "::endgroup::"
done < "$FEEDS"

"${here}/build-index.sh" "$SITE" "$FEEDS" "$BASE_URL"

if (( failed > 0 )); then
  echo "build-all: ${failed} feed(s) failed" >&2
  exit 1
fi
