# iriarte.it — Personal Blog

Source code for [iriarte.it](https://iriarte.it), a Jekyll-based personal blog covering Linux, infrastructure, virtualization, networking, and programming.

## Tech Stack

- **Generator:** [Jekyll](https://jekyllrb.com/) via GitHub Pages
- **Theme:** [Minima](https://github.com/jekyll/minima) (remote theme)
- **Hosting:** GitHub Pages with custom domain `iriarte.it`
- **Plugins:** jekyll-feed, jekyll-seo-tag, jekyll-sitemap, jekyll-compose

## Local Development

```bash
# Install dependencies
gem install bundler
bundle install

# Serve locally (live reload at http://localhost:4000)
bundle exec jekyll serve

# Build for production
bundle exec jekyll build
```

## Directory Structure

```
.
├── _config.yml          # Site configuration (title, URL, plugins, defaults)
├── _posts/              # Blog posts (Markdown with YAML front matter)
├── _includes/           # Reusable HTML snippets included in posts
├── assets/              # Static files (CSS, images)
├── code/                # Example code referenced by posts
├── Gemfile              # Ruby gem dependencies
└── CNAME                # Custom domain for GitHub Pages
```

## Writing Posts

Posts live in `_posts/` and follow the naming convention:

```
YYYY-MM-DD-post-title.md
```

### Front Matter

Each post requires YAML front matter. Use `jekyll compose` to scaffold a new post:

```bash
bundle exec jekyll post "My Post Title"
```

Standard fields:

```yaml
---
title: 'Post Title'
date: 'YYYY-MM-DDTHH:MM:SS-04:00'
author: Ciro Iriarte
layout: post
description: '1–2 sentence summary for SEO and social cards.'
categories:
    - Linux
tags:
    - linux
    - networking
published: true
---
```

Optional fields:

| Field | Description |
|---|---|
| `description` | Used by `jekyll-seo-tag` for meta descriptions and social cards |
| `deprecated: true` | Marks posts covering EOL software — can be used by the theme for a banner |
| `excerpt` | Short summary used in some listing contexts |

### Excerpt Separator

Add `<!-- more -->` after the first meaningful paragraph to control what appears in post listings and the homepage preview.

## Tag Vocabulary

Use these tags consistently to keep navigation working:

`linux`, `networking`, `virtualization`, `storage`, `security`, `monitoring`, `opensuse`, `sles`, `windows`, `bash`, `ssh`, `apache`, `nagios`, `backup`, `timezone`, `java`, `oracle`, `powershell`, `gps`, `sysadmin`, `nonsense`, `meta`

## Deployment

Commits pushed to the `main` branch are automatically built and deployed by GitHub Pages. The live site is available at [https://iriarte.it](https://iriarte.it).

## Content

The blog spans 2006–2025 with 40+ published posts in English and Spanish. Topics include:

- Linux system administration (SLES, openSUSE)
- Virtualization (VirtualBox, Proxmox, VMware)
- Networking and monitoring (Nagios, Observium, Apstra)
- Storage (Hitachi VSP, EMC Symmetrix)
- Personal projects and anecdotes
