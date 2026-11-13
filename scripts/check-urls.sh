#!/usr/bin/env bash
# Verify that every URL the live site served before the modernization
# (scripts/baseline/files.txt) still exists in a build, either as a page or
# as a redirect, unless it's listed in scripts/baseline/allowed-removals.txt.
# Also checks that feed entries present in the baseline feed keep their <id>,
# so feed readers don't show posts twice.
#
# Usage: scripts/check-urls.sh [SITE_DIR]
#   Without SITE_DIR, builds a fresh production site into a temporary
#   directory. Pass SITE_DIR only for a build you just made.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -ge 1 ]]; then
  site="$1"
else
  site=$(mktemp -d)
  trap 'rm -rf "$site"' EXIT
  JEKYLL_ENV=production bundle exec jekyll build -q -d "$site"
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

# Feed entry ids. jekyll-feed uses the post URL as the entry <id>. Every id in
# the baseline feed must either still be an entry in the new feed, or (once the
# post has scrolled out of the feed window) still be a real page, not a
# redirect stub: a redirect means the post moved and readers would see it again
# under a new id.
python3 -I - scripts/baseline/feed.xml "$site" <<'PY'
import os, sys, xml.etree.ElementTree as ET
from urllib.parse import urlparse
ns = {"a": "http://www.w3.org/2005/Atom"}
def ids(path):
    return [e.findtext("a:id", namespaces=ns) for e in ET.parse(path).getroot().findall("a:entry", ns)]
baseline_ids, site = ids(sys.argv[1]), sys.argv[2]
new_ids = set(ids(os.path.join(site, "feed.xml")))
if not new_ids:
    sys.exit("FAIL: generated feed has no entries")
bad = 0
for i in baseline_ids:
    if i in new_ids:
        continue
    # ids drop the .html extension (Jekyll's post.id), so try the variants
    base = os.path.join(site, urlparse(i).path.lstrip("/"))
    f = next((c for c in (base, base + ".html", os.path.join(base, "index.html"))
              if os.path.isfile(c)), None)
    if f is None:
        print(f"FEED ID GONE: {i}"); bad += 1
    elif 'http-equiv="refresh"' in open(f, encoding="utf-8", errors="replace").read():
        print(f"FEED ID MOVED (now a redirect): {i}"); bad += 1
if bad:
    sys.exit(1)
kept = sum(i in new_ids for i in baseline_ids)
print(f"OK: feed ids stable ({kept} of {len(baseline_ids)} baseline entries still in the feed, rest still served)")
PY
