#!/usr/bin/env bash
# Cut a release tarball and update Formula/claude-clean.rb with its sha256.
#
#   scripts/release.sh 1.0.1 [github-user/repo]
set -euo pipefail

VERSION="${1:?usage: release.sh <version> [user/repo]}"
REPO="${2:-HarsimarSingh23/claude-clean}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Keep the script's own VERSION in lockstep with the tag.
sed -i '' -E "s/^VERSION=\"[^\"]+\"/VERSION=\"$VERSION\"/" bin/claude-clean
grep -q "VERSION=\"$VERSION\"" bin/claude-clean || { echo "failed to stamp version"; exit 1; }

mkdir -p dist
TARBALL="dist/claude-clean-$VERSION.tar.gz"

# Mirror GitHub's archive layout: a single top-level <name>-<version>/ dir.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/claude-clean-$VERSION"
cp -R bin Formula scripts README.md LICENSE "$STAGE/claude-clean-$VERSION/" 2>/dev/null || true
tar -czf "$TARBALL" -C "$STAGE" "claude-clean-$VERSION"

SHA="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"

sed -i '' -E \
  -e "s|url \".*\"|url \"https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz\"|" \
  -e "s|sha256 \"[0-9a-f]*\"|sha256 \"$SHA\"|" \
  -e "s|homepage \".*\"|homepage \"https://github.com/$REPO\"|" \
  -e "s|head \".*\", branch|head \"https://github.com/$REPO.git\", branch|" \
  Formula/claude-clean.rb

echo "built   $TARBALL"
echo "sha256  $SHA"
echo
echo "Next:"
echo "  git add -A && git commit -m \"release v$VERSION\""
echo "  git tag v$VERSION && git push origin main --tags"
echo "  gh release create v$VERSION $TARBALL --title v$VERSION --generate-notes"
