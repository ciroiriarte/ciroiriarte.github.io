# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jekyll 4.4 personal blog (iriarte.it) built by GitHub Actions and deployed to GitHub Pages. Theme: minima as `remote_theme`, pinned to a commit in `_config.yml` (unreleased 3.0-dev), with local overrides in `_layouts/`, `_includes/` and `_sass/minima/`. See README.md for the full authoring guide.

## Commands

The host Ruby can't build native gems, so use the Docker wrapper (ruby from `.ruby-version`):

```bash
scripts/docker-jekyll.sh serve --livereload --drafts     # http://localhost:4000
JEKYLL_ENV=production scripts/docker-jekyll.sh build     # -> _site/
npx -y pagefind@1.4.0                                    # search index into _site/pagefind
scripts/check-urls.sh _site                              # no live URL may disappear
```

`JEKYLL_ENV=production` is required for the GA4 and GoatCounter tags.

## Rules

- Never change an existing post's URL. Every post before 2026-11 has an explicit `permalink:`; new posts use `/:year/:month/:day/:title.html`. `scripts/check-urls.sh` enforces this in CI; intentional removals go in `scripts/baseline/allowed-removals.txt`.
- `categories` and `tags` must be keys in `_data/taxonomy.yml` (lowercase, hyphenated). Add new keys there first.
- Every post has `lang: en|es` and a `description:`.
- Images live in `assets/img/YYYY-MM-DD-*.{png,jpg}` and are embedded with `{% include image.html url=... description=... alt=... width=... height=... %}`.
- Series: `series`, `series_part`, `series_title` front matter plus `{% include series-nav.html %}`; series names in `_data/series.yml`.
- `deprecated: true` marks posts about end-of-life software (banner + badge).
- `<!--more-->` is the excerpt separator.
- Multiple authors: add them to `_data/authors.yml`; the post's `author:` must match the key.

## Hosting

- GitHub Pages, source = GitHub Actions (`.github/workflows/pages.yml`), custom domain iriarte.it via `CNAME`.
