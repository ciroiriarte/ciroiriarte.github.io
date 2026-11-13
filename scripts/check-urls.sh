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

# Feed entry ids: an entry whose title was in the baseline feed must keep its id.
python3 -I - scripts/baseline/feed.xml "$site/feed.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"a": "http://www.w3.org/2005/Atom"}
def entries(path):
    return {e.findtext("a:title", namespaces=ns): e.findtext("a:id", namespaces=ns)
            for e in ET.parse(path).getroot().findall("a:entry", ns)}
old, new = entries(sys.argv[1]), entries(sys.argv[2])
changed = [(t, old[t], new[t]) for t in old if t in new and old[t] != new[t]]
for t, a, b in changed:
    print(f"FEED ID CHANGED: {t!r}: {a} -> {b}")
if changed:
    sys.exit(1)
print(f"OK: feed ids stable ({sum(t in new for t in old)} baseline entries still in the feed)")
PY
