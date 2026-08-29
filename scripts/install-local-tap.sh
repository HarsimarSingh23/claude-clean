#!/usr/bin/env bash
# Install claude-clean via Homebrew from THIS checkout, without needing GitHub.
# Creates a local tap pointing at a file:// tarball.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAP="local/claude-clean"
VERSION="$(awk -F'"' '/^VERSION=/{print $2; exit}' "$ROOT/bin/claude-clean")"

command -v brew >/dev/null || { echo "Homebrew not found"; exit 1; }

brew tap "$TAP" 2>/dev/null || brew tap-new "$TAP" --no-git 2>/dev/null || true
TAPDIR="$(brew --repository "$TAP")"
mkdir -p "$TAPDIR/Formula"

mkdir -p "$ROOT/dist"
TARBALL="$ROOT/dist/claude-clean-$VERSION.tar.gz"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/claude-clean-$VERSION"
cp -R "$ROOT/bin" "$STAGE/claude-clean-$VERSION/"
[ -f "$ROOT/README.md" ] && cp "$ROOT/README.md" "$STAGE/claude-clean-$VERSION/"
[ -f "$ROOT/LICENSE" ]   && cp "$ROOT/LICENSE"   "$STAGE/claude-clean-$VERSION/"
tar -czf "$TARBALL" -C "$STAGE" "claude-clean-$VERSION"
SHA="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"

cat > "$TAPDIR/Formula/claude-clean.rb" <<RB
class ClaudeClean < Formula
  desc "Audit and slim down Claude Code's startup context and on-disk state"
  homepage "https://github.com/HarsimarSingh23/claude-clean"
  url "file://$TARBALL"
  sha256 "$SHA"
  version "$VERSION"
  license "MIT"

  def install
    bin.install "bin/claude-clean"
  end

  test do
    assert_match "claude-clean #{version}", shell_output("#{bin}/claude-clean --version")
  end
end
RB

brew reinstall "$TAP/claude-clean"
echo
echo "Installed: $(command -v claude-clean)"
claude-clean --version
