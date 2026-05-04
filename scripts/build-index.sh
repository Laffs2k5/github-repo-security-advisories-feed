#!/usr/bin/env bash
# build-index.sh — emit a simple HTML landing page listing all generated feeds.
#
# Usage:
#   build-index.sh <site-dir> <feeds-file> <base-url>
#
# Reads feeds-file (one `owner/repo` per line, # comments allowed) and writes
# <site-dir>/index.html linking each <site-dir>/<owner>--<repo>.atom file.

set -euo pipefail

SITE="${1:?usage: $0 <site-dir> <feeds-file> <base-url>}"
FEEDS="${2:?usage: $0 <site-dir> <feeds-file> <base-url>}"
BASE_URL="${3:?usage: $0 <site-dir> <feeds-file> <base-url>}"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
out="${SITE}/index.html"

{
  cat <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>GitHub repo security advisories — Atom feeds</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; max-width: 48rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    h1 { margin-bottom: 0.25rem; }
    .sub { color: #555; margin-top: 0; }
    ul { padding-left: 1.25rem; }
    li { margin: 0.5rem 0; }
    code { background: #f3f3f3; padding: 0.1rem 0.3rem; border-radius: 3px; }
    .footer { color: #777; font-size: 0.9em; margin-top: 2rem; }
  </style>
</head>
<body>
  <h1>GitHub repo security advisories</h1>
  <p class="sub">Atom feeds rebuilt hourly from GitHub's <a href="https://docs.github.com/en/rest/security-advisories/repository-advisories">repository security advisories</a> API.</p>
  <h2>Feeds</h2>
  <ul>
EOF

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    repo="$line"
    slug="${repo/\//--}"
    feed_md="${BASE_URL%/}/${slug}.atom"
    feed_html="${BASE_URL%/}/${slug}.html.atom"
    repo_url="https://github.com/${repo}/security/advisories"
    echo "    <li><code>${repo}</code> &middot; <a href=\"${feed_md}\">markdown feed</a> &middot; <a href=\"${feed_html}\">HTML feed</a> &middot; <a href=\"${repo_url}\">advisories on GitHub</a></li>"
  done < "$FEEDS"

  cat <<EOF
  </ul>
  <p class="footer">Last built: ${now} &middot; <a href="https://github.com/Laffs2k5/github-repo-security-advisories-feed">source</a></p>
</body>
</html>
EOF
} > "$out"

echo "wrote $out"
