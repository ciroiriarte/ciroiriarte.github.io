# iriarte.it: personal blog

Source for [iriarte.it](https://iriarte.it), a Jekyll blog about Linux, virtualization, networking, storage and backup.

## Tech stack

- **Generator:** [Jekyll](https://jekyllrb.com/) 4.4, built by GitHub Actions (`.github/workflows/pages.yml`) and deployed to GitHub Pages
- **Theme:** [Minima](https://github.com/jekyll/minima) as a remote theme, pinned to a commit in `_config.yml`, with local overrides in `_layouts/`, `_includes/` and `_sass/minima/`
- **Plugins:** jekyll-feed, jekyll-seo-tag, jekyll-sitemap, jekyll-remote-theme, jekyll-redirect-from, jekyll-compose (local only)
- **Search:** [Pagefind](https://pagefind.app/), indexed after the Jekyll build (`pagefind.yml`)
- **Analytics:** Google Analytics 4, plus an optional cookieless [GoatCounter](https://www.goatcounter.com/) counter (`goatcounter:` in `_config.yml`). Both are emitted only when `JEKYLL_ENV=production`.
- **Hosting:** GitHub Pages with the custom domain `iriarte.it` (`CNAME`)

## Local development

The repository pins Ruby in `.ruby-version` (the same version CI uses). The easiest way to get it is the Docker wrapper, which needs nothing installed on the host but Docker:

```bash
scripts/docker-jekyll.sh serve --livereload --drafts   # http://localhost:4000
JEKYLL_ENV=production scripts/docker-jekyll.sh build   # -> _site/
```

With a local Ruby that matches `.ruby-version`:

```bash
bundle install
bundle exec jekyll serve --livereload --drafts
```

Search only works on a built site, because the index is generated afterwards:

```bash
JEKYLL_ENV=production scripts/docker-jekyll.sh build
npx -y pagefind@1.4.0 --serve          # http://localhost:1414
```

### URL check

`scripts/check-urls.sh [_site]` fails if any URL the site served before the Jekyll 4 migration (`scripts/baseline/files.txt`) is missing from a build. Paths removed on purpose are listed in `scripts/baseline/allowed-removals.txt`. CI runs it before every deploy, so a post can't silently change address.

## Directory structure

```
.
├── _config.yml            # Site configuration
├── _posts/                # Published posts (YYYY-MM-DD-title.md)
├── _drafts/               # Unpublished drafts (served with --drafts)
├── _data/
│   ├── taxonomy.yml       # Allowed topics (categories) and tags
│   ├── series.yml         # Multi-part series names
│   └── authors.yml        # Author bios shown under posts
├── _includes/             # Overrides and snippets (image, series nav, header, footer...)
├── _layouts/              # Overrides of minima's post and home layouts
├── _sass/minima/          # Style overrides (custom-variables.scss, custom-styles.scss)
├── assets/                # Images (assets/img/YYYY-MM-DD-*.png) and JS
├── topics.md, tags.md, archive.md, search.md, about.markdown
├── scripts/               # check-urls.sh, docker-jekyll.sh, URL baseline
└── .github/workflows/     # Build and deploy
```

## Writing posts

Scaffold a draft with `bundle exec jekyll draft "My Post Title"` (or create the file by hand), then move it to `_posts/` with a date prefix when it's ready.

```yaml
---
title: 'Post title'
date: 2026-11-13 10:00:00 -0300
description: '1–2 sentence summary for search results and social cards.'
lang: en                 # or es
categories:              # topic keys from _data/taxonomy.yml
  - virtualization
tags:                    # tag keys from _data/taxonomy.yml
  - proxmox
---
```

New posts get `/:year/:month/:day/:title.html` URLs. Older posts carry an explicit `permalink:`, so don't remove it.

Optional fields:

| Field | Effect |
|---|---|
| `image` | Social card image; defaults to `/assets/img/og-default.png` |
| `deprecated: true` | Shows an "outdated" banner and badge (end-of-life software) |
| `series`, `series_part`, `series_title` | Adds the post to a series from `_data/series.yml`; place `{% include series-nav.html %}` where the navigation should appear |
| `modified_date` | Shows an "Updated" date |
| `redirect_from` | Old URLs that should redirect to this post |

Put `<!--more-->` after the first paragraph to mark the excerpt. Images go through the include, which lazy-loads them and adds a caption:

```liquid
{% include image.html url="/assets/img/2026-11-13-example.png" description="Caption" alt="What the image shows" width=1200 height=800 %}
```

## Topics and tags

Topics and tags are a controlled vocabulary in [`_data/taxonomy.yml`](_data/taxonomy.yml). Add a key there before using it in a post; the key is the URL anchor on `/topics/` and `/tags/`, and `name` is what readers see.

## Deployment

Pushing to `main` runs `.github/workflows/pages.yml`: Jekyll build (production), Pagefind index, URL check, then deploy with `actions/deploy-pages`. The repository's Pages source must be set to **GitHub Actions** (Settings → Pages).
