#!/usr/bin/env bash
# Cut a release of claude-clean and update the Homebrew tap.
#
#   scripts/release.sh 1.0.2 [source-repo] [tap-repo]
#
# The formula deliberately lives in a SEPARATE tap repo. A formula stored inside
# the tarball it checksums is self-referential: editing the formula changes the
# tarball, which changes the sha256, which requires editing the formula.
set -euo pipefail

VERSION="${1:?usage: release.sh <version> [source-repo] [tap-repo]}"
REPO="${2:-HarsimarSingh23/claude-clean}"
TAP_REPO="${3:-HarsimarSingh23/homebrew-claude-clean}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

sed -i '' -E "s/^VERSION=\"[^\"]+\"/VERSION=\"$VERSION\"/" bin/claude-clean
grep -q "VERSION=\"$VERSION\"" bin/claude-clean || { echo "failed to stamp version"; exit 1; }
bash -n bin/claude-clean || { echo "syntax check failed"; exit 1; }

git add -A
git diff --cached --quiet || git commit -m "release v$VERSION"
git push origin main

# Always a fresh tag name: GitHub caches archive tarballs per tag, so reusing or
# moving a tag can serve a stale artifact and break the published checksum.
git rev-parse "v$VERSION" >/dev/null 2>&1 && { echo "tag v$VERSION already exists; bump the version"; exit 1; }
git tag -a "v$VERSION" -m "claude-clean v$VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" --title "v$VERSION" --generate-notes

URL="https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz"
echo "waiting for the release tarball..."
for _ in $(seq 1 10); do
  curl -fsL "$URL" -o /tmp/cc-release.tgz 2>/dev/null && break
  sleep 3
done
SHA="$(shasum -a 256 /tmp/cc-release.tgz | awk '{print $1}')"
echo "sha256 $SHA"

TAP_DIR="$(mktemp -d)"
git clone -q "https://github.com/$TAP_REPO.git" "$TAP_DIR"
mkdir -p "$TAP_DIR/Formula"
sed -e "s|__VERSION__|$VERSION|g" -e "s|__SHA__|$SHA|g" -e "s|__REPO__|$REPO|g" \
    "$ROOT/packaging/claude-clean.rb.tmpl" > "$TAP_DIR/Formula/claude-clean.rb"
git -C "$TAP_DIR" add -A
git -C "$TAP_DIR" commit -q -m "claude-clean $VERSION"
git -C "$TAP_DIR" push -q origin HEAD
rm -rf "$TAP_DIR"

echo
echo "Released v$VERSION and updated tap $TAP_REPO"
echo "  brew update && brew upgrade claude-clean"
