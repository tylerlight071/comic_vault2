#!/usr/bin/env bash
# bump_version.sh
#
# Usage:
#   ./scripts/bump_version.sh          → bumps the build number (1.0.0+1 → 1.0.0+2)
#   ./scripts/bump_version.sh patch    → bumps patch + resets build (1.0.0+1 → 1.0.1+1)
#   ./scripts/bump_version.sh minor    → bumps minor + resets patch & build
#   ./scripts/bump_version.sh major    → bumps major + resets everything
#
# Also updates version.json in the repo root to match the new semver.

set -euo pipefail

PUBSPEC="pubspec.yaml"
VERSION_JSON="version.json"

# ── Read current version ──────────────────────────────────────────────────────
current=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed 's/version: //')
semver="${current%%+*}"    # e.g. 1.0.0
build="${current##*+}"     # e.g. 1

IFS='.' read -r major minor patch <<< "$semver"

# ── Bump ──────────────────────────────────────────────────────────────────────
mode="${1:-build}"

case "$mode" in
  major)
    major=$((major + 1)); minor=0; patch=0; build=1 ;;
  minor)
    minor=$((minor + 1)); patch=0; build=1 ;;
  patch)
    patch=$((patch + 1)); build=1 ;;
  build)
    build=$((build + 1)) ;;
  *)
    echo "Unknown bump mode: $mode. Use major | minor | patch | build"; exit 1 ;;
esac

new_semver="$major.$minor.$patch"
new_version="$new_semver+$build"

# ── Write pubspec.yaml ────────────────────────────────────────────────────────
sed -i "s/^version: .*/version: $new_version/" "$PUBSPEC"

# ── Write version.json ────────────────────────────────────────────────────────
# Preserves existing forceUpdate and changelog values.
tmp=$(mktemp)
node -e "
  const fs = require('fs');
  const j = JSON.parse(fs.readFileSync('$VERSION_JSON', 'utf8'));
  j.version = '$new_semver';
  fs.writeFileSync('$tmp', JSON.stringify(j, null, 2) + '\n');
" 2>/dev/null || python3 -c "
import json, sys
with open('$VERSION_JSON') as f:
    j = json.load(f)
j['version'] = '$new_semver'
with open('$tmp', 'w') as f:
    json.dump(j, f, indent=2)
    f.write('\n')
"
mv "$tmp" "$VERSION_JSON"

echo "Bumped: $current → $new_version"
