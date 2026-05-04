#!/usr/bin/env bash
# ghsa-to-atom.sh — fetch a repo's published security advisories and emit an Atom feed.
#
# Usage:
#   ghsa-to-atom.sh <owner/repo> <output-atom-path> <public-feed-url>
#
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN), jq.

set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> <output-atom-path> <public-feed-url>}"
OUT="${2:?usage: $0 <owner/repo> <output-atom-path> <public-feed-url>}"
SELF_URL="${3:?usage: $0 <owner/repo> <output-atom-path> <public-feed-url>}"

mkdir -p "$(dirname "$OUT")"

tmp_json="$(mktemp)"
trap 'rm -f "$tmp_json"' EXIT

# `gh api --paginate` concatenates JSON array pages into a single array.
# state=published filters out drafts; we re-build the full feed every run.
gh api --paginate \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/security-advisories?state=published&per_page=100" \
  > "$tmp_json"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
feed_id="tag:github.com,2008:/repos/${REPO}/security-advisories"
html_url="https://github.com/${REPO}/security/advisories"

entries="$(jq -r --arg repo "$REPO" '
  def xmlesc:
    tostring
    | gsub("&"; "&amp;")
    | gsub("<"; "&lt;")
    | gsub(">"; "&gt;")
    | gsub("\""; "&quot;");

  sort_by(.published_at) | reverse | .[] |
  "  <entry>\n" +
  "    <id>tag:github.com,2008:GHSA/" + .ghsa_id + "</id>\n" +
  "    <title type=\"html\">[" + .ghsa_id + "] " +
        ((.severity // "unknown") | ascii_upcase) + ": " +
        ((.summary // "(no summary)") | xmlesc) + "</title>\n" +
  "    <link rel=\"alternate\" type=\"text/html\" href=\"" + (.html_url | xmlesc) + "\"/>\n" +
  "    <published>" + .published_at + "</published>\n" +
  "    <updated>"   + (.updated_at // .published_at) + "</updated>\n" +
  (if .cve_id then "    <category term=\"" + (.cve_id | xmlesc) + "\"/>\n" else "" end) +
  "    <category term=\"severity:" + ((.severity // "unknown") | xmlesc) + "\"/>\n" +
  "    <content type=\"html\">" +
        ((.description // .summary // "") | xmlesc) +
  "</content>\n" +
  "    <author><name>" + ($repo | xmlesc) + "</name></author>\n" +
  "  </entry>"
' "$tmp_json")"

out_tmp="${OUT}.tmp.$$"
{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en-US">
  <id>${feed_id}</id>
  <link rel="self" type="application/atom+xml" href="${SELF_URL}"/>
  <link rel="alternate" type="text/html" href="${html_url}"/>
  <title>Security advisories — ${REPO}</title>
  <updated>${now}</updated>
  <author><name>github-repo-security-advisories-feed</name></author>
EOF
  printf '%s\n' "$entries"
  echo '</feed>'
} > "$out_tmp"

mv -f "$out_tmp" "$OUT"
echo "wrote $OUT ($(wc -c <"$OUT") bytes, $(jq 'length' "$tmp_json") advisories)"
