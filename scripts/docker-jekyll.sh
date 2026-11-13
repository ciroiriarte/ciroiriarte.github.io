#!/usr/bin/env bash
# Run Jekyll in the same Ruby version CI uses, without touching the host Ruby.
#   scripts/docker-jekyll.sh build            # -> _site
#   scripts/docker-jekyll.sh serve --livereload
#   scripts/docker-jekyll.sh exec <cmd...>    # run any command in the container
set -euo pipefail
cd "$(dirname "$0")/.."
ruby_version=$(cat .ruby-version 2>/dev/null || echo 3.3)
port=()
[[ "${1:-}" == serve ]] && port=(-p 4000:4000 -p 35729:35729)
if [[ "${1:-}" == exec ]]; then shift; cmd=("$@"); else cmd=(bundle exec jekyll "$@"); fi
[[ "${1:-}" == serve ]] && cmd+=(--host 0.0.0.0)
exec docker run --rm -t "${port[@]}" \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -e JEKYLL_ENV="${JEKYLL_ENV:-development}" \
  -e BUNDLE_PATH=/bundle -e BUNDLE_APP_CONFIG=/tmp/.bundle \
  -v blog-bundle:/bundle -v "$PWD":/srv -w /srv \
  "ruby:${ruby_version}" bash -c 'bundle check >/dev/null 2>&1 || bundle install --quiet; exec "$@"' _ "${cmd[@]}"
