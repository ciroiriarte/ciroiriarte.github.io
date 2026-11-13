source "https://rubygems.org"

# Built by GitHub Actions (.github/workflows/pages.yml), not the classic
# github-pages gem, so any Jekyll version and plugin can be used.
gem "jekyll", "~> 4.4"

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jekyll-remote-theme"
  gem "jekyll-redirect-from"
  gem "jekyll-compose", group: :development
end

# Liquid 4 needs these, and they left Ruby's default gems in 3.4/3.5.
# (webrick, csv and base64 already come in as Jekyll dependencies.)
gem "bigdecimal"
gem "logger"
