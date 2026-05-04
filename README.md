# github-repo-security-advisories-feed

Atom feeds for GitHub repository security advisories, rebuilt hourly and
published via GitHub Pages: <https://laffs2k5.github.io/github-repo-security-advisories-feed/>

GitHub publishes advisories per repo as HTML pages but not as a feed. This repo
polls the [repository security advisories REST API][api] for each configured
repo and turns the result into Atom feeds you can subscribe to.

[api]: https://docs.github.com/en/rest/security-advisories/repository-advisories

## Subscribed repos

Listed in [`feeds.txt`](./feeds.txt). To add another repo, append a line of the
form `owner/repo` and open a PR. Lines starting with `#` are ignored.

## Output

Each subscribed repo gets two Atom feeds:

| File | Body content | Use case |
| ---- | ------------ | -------- |
| `<owner>--<repo>.atom` | Raw GitHub-flavored markdown (advisory body verbatim) | Plain-text-friendly readers; archival |
| `<owner>--<repo>.html.atom` | Pandoc-rendered HTML | Mail-via-feed readers like Blogtrottr that render `<content type="html">` |

For example:

- <https://laffs2k5.github.io/github-repo-security-advisories-feed/opnsense--core.atom>
- <https://laffs2k5.github.io/github-repo-security-advisories-feed/opnsense--core.html.atom>

A landing page at the Pages root (`index.html`) lists every feed.

The two feeds carry distinct `<id>`s, entry-id suffixes, and `<title>`s so feed
readers treat them as separate subscriptions.

## How it works

- `.github/workflows/build-feeds.yml` runs hourly (and on push / manually). It
  installs pandoc via [`pandoc/actions/setup`][pandoc-action], builds the site,
  and deploys it to GitHub Pages with the official Pages actions.
- `scripts/build-all.sh` iterates `feeds.txt` and, for each repo:
  - Calls `scripts/ghsa-to-atom.sh` twice — once with `format=markdown`, once
    with `format=html` — to produce both Atom files.
  - At the end, calls `scripts/build-index.sh` to write the landing page.
- `scripts/ghsa-to-atom.sh` fetches `state=published` advisories with
  `gh api --paginate` and emits an Atom file. In `html` mode it pipes each
  advisory's `description` through `pandoc -f gfm -t html --wrap=none` before
  embedding it in `<content type="html">`.
- Each feed is prefixed with a UTF-8 BOM. GitHub Pages serves `.atom` as
  `application/atom+xml` with no charset; the BOM makes the encoding
  self-describing per [RFC 3023][rfc3023] so clients don't fall back to
  Latin-1 and mojibake the bytes.

The feeds are regenerated from scratch every run — no state is tracked outside
the JSON snapshot from GitHub, so the job is idempotent.

[pandoc-action]: https://github.com/pandoc/actions
[rfc3023]: https://www.rfc-editor.org/rfc/rfc3023

## One-time setup

After pushing this repo to GitHub:

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Trigger the workflow once via the **Actions** tab → *Build and publish
   advisory feeds* → **Run workflow**.
3. The first deploy publishes the feeds at the URL shown in the workflow's
   `deploy` job output.

No secrets needed — the workflow uses the default `GITHUB_TOKEN`, which is
sufficient for reading public advisories at the 1000 req/h authenticated rate.

## Local testing

Requires `gh` (authenticated), `jq`, and `pandoc`.

```sh
GH_TOKEN=$(gh auth token) \
  ./scripts/build-all.sh site feeds.txt http://localhost:8000
```

Output appears in `site/`. To preview the landing page locally:

```sh
python3 -m http.server -d site 8000
```
