#!/usr/bin/env bash
# Verify that every URL served by the live site before the modernization
# (scripts/baseline/files.txt) still exists in a build, or is served by a
# redirect page, or is listed in scripts/baseline/allowed-removals.txt.
#
# Usage: scripts/check-urls.sh [SITE_DIR]   (default: _site, built if missing)
set -euo pipefail
cd "$(dirname "$0")/.."
site="${1:-_site}"
if [[ ! -d "$site" ]]; then
  JEKYLL_ENV=production bundle exec jekyll build -d "$site" >/dev/null
fi

baseline=scripts/baseline/files.txt
allowed=scripts/baseline/allowed-removals.txt
missing=0
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ -f "$allowed" ]] && grep -qxF "$path" "$allowed"; then
    continue
  fi
  f="$site$path"
  # /x/ and /x/index.html are the same URL
  [[ "$path" == */ ]] && f="${f}index.html"
  if [[ ! -f "$f" ]]; then
    echo "MISSING: $path"
    missing=$((missing + 1))
  fi
done < "$baseline"

total=$(grep -c . "$baseline")
if (( missing > 0 )); then
  echo "FAIL: $missing of $total baseline URLs missing from $site"
  exit 1
fi
echo "OK: all $total baseline URLs present in $site"
