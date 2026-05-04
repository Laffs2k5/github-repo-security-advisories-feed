#!/usr/bin/env bash
# ghsa-to-atom.sh — fetch a repo's published security advisories and emit an Atom feed.
#
# Usage:
#   ghsa-to-atom.sh <owner/repo> <output-atom-path> <public-feed-url> [format]
#
# format: markdown (default) | html
#   markdown: <content> contains the raw advisory body (GitHub markdown).
#   html:     <content> contains pandoc-rendered HTML — pleasant in mail readers.
#
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN), jq, and pandoc when
# format=html.

set -euo pipefail

USAGE="usage: $0 <owner/repo> <output-atom-path> <public-feed-url> [markdown|html]"
REPO="${1:?$USAGE}"
OUT="${2:?$USAGE}"
SELF_URL="${3:?$USAGE}"
FORMAT="${4:-markdown}"

case "$FORMAT" in
  markdown|html) ;;
  *) echo "invalid format: $FORMAT ($USAGE)" >&2; exit 2 ;;
esac

if [[ "$FORMAT" == "html" ]] && ! command -v pandoc >/dev/null; then
  echo "pandoc is required for format=html but was not found on PATH" >&2
  exit 1
fi

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

# For html format, replace each advisory's `description` markdown body with
# pandoc-rendered HTML in place. The jq template below then xml-escapes that
# HTML, which is exactly what <content type="html"> expects per Atom spec.
if [[ "$FORMAT" == "html" ]]; then
  augmented="$(mktemp)"
  trap 'rm -f "$tmp_json" "$augmented"' EXIT
  jq -c '.[]' "$tmp_json" | while IFS= read -r item; do
    body=$(jq -r '.description // .summary // ""' <<<"$item")
    if [[ -n "$body" ]]; then
      rendered=$(printf '%s' "$body" | pandoc -f gfm -t html --wrap=none)
    else
      rendered=""
    fi
    jq -c --arg html "$rendered" '.description = $html' <<<"$item"
  done | jq -s '.' > "$augmented"
  mv "$augmented" "$tmp_json"
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
html_url="https://github.com/${REPO}/security/advisories"
# Each format gets a distinct feed id, entry id suffix, and title so subscribers
# treat them as separate feeds.
if [[ "$FORMAT" == "html" ]]; then
  feed_id="tag:github.com,2008:/repos/${REPO}/security-advisories:html"
  entry_id_suffix=":html"
  feed_title="Security advisories (HTML) — ${REPO}"
else
  feed_id="tag:github.com,2008:/repos/${REPO}/security-advisories"
  entry_id_suffix=""
  feed_title="Security advisories — ${REPO}"
fi

entries="$(jq -r --arg repo "$REPO" --arg id_suffix "$entry_id_suffix" '
  def xmlesc:
    tostring
    | gsub("&"; "&amp;")
    | gsub("<"; "&lt;")
    | gsub(">"; "&gt;")
    | gsub("\""; "&quot;");

  sort_by(.published_at) | reverse | .[] |
  "  <entry>\n" +
  "    <id>tag:github.com,2008:GHSA/" + .ghsa_id + $id_suffix + "</id>\n" +
  "    <title type=\"html\">" +
        ((.severity // "unknown") | ascii_upcase) + " — " +
        ((.summary // "(no summary)") | xmlesc) +
        " (" + ([.cve_id, .ghsa_id] | map(select(. != null and . != "")) | join(", ") | xmlesc) + ")" +
        "</title>\n" +
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
# UTF-8 BOM: GitHub Pages serves .atom as application/atom+xml without a
# charset, and some clients then default to Latin-1 and mojibake the bytes.
# A BOM makes the encoding self-describing per RFC 3023, regardless of header.
printf '\xEF\xBB\xBF' > "$out_tmp"
{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en-US">
  <id>${feed_id}</id>
  <link rel="self" type="application/atom+xml" href="${SELF_URL}"/>
  <link rel="alternate" type="text/html" href="${html_url}"/>
  <title>${feed_title}</title>
  <updated>${now}</updated>
  <author><name>github-repo-security-advisories-feed</name></author>
EOF
  printf '%s\n' "$entries"
  echo '</feed>'
} >> "$out_tmp"

mv -f "$out_tmp" "$OUT"
echo "wrote $OUT ($(wc -c <"$OUT") bytes, $(jq 'length' "$tmp_json") advisories)"
