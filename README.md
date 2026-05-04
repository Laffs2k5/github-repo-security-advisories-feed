# github-repo-security-advisories-feed

Atom feeds for GitHub repository security advisories, rebuilt hourly and
published via GitHub Pages.

GitHub publishes advisories per repo as HTML pages but not as a feed. This repo
polls the [repository security advisories REST API][api] for each configured
repo and turns the result into an Atom feed you can subscribe to.

[api]: https://docs.github.com/en/rest/security-advisories/repository-advisories

## Subscribed repos

Listed in [`feeds.txt`](./feeds.txt). To add another repo, append a line of the
form `owner/repo` and open a PR. Lines starting with `#` are ignored.

## Output

Once Pages is enabled, each repo gets a feed at:

```
https://<user>.github.io/<this-repo>/<owner>--<repo>.atom
```

A landing page at the Pages root (`index.html`) lists all feeds.

## How it works

- `.github/workflows/build-feeds.yml` runs hourly (and on push / manually).
- `scripts/build-all.sh` iterates `feeds.txt` and:
  - Calls `scripts/ghsa-to-atom.sh` per repo, which uses `gh api --paginate` to
    fetch all `state=published` advisories and emits an Atom file.
  - Calls `scripts/build-index.sh` to write a small landing page.
- The workflow uploads the `site/` directory as a Pages artifact and deploys it.

The feed is regenerated from scratch every run — no state is tracked outside
the JSON snapshot from GitHub, so the job is idempotent.

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

```sh
# Requires gh (authenticated) and jq.
GH_TOKEN=$(gh auth token) \
  ./scripts/build-all.sh site feeds.txt http://localhost:8000
```
