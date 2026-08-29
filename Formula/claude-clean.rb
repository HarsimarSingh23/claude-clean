# Homebrew formula for claude-clean.
#
# Publish by pushing this repo to GitHub, tagging a release, then running
# scripts/release.sh — it rewrites the url/sha256 below for you.
class ClaudeClean < Formula
  desc "Audit and slim down Claude Code's startup context and on-disk state"
  homepage "https://github.com/HarsimarSingh23/claude-clean"
  url "https://github.com/HarsimarSingh23/claude-clean/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/HarsimarSingh23/claude-clean.git", branch: "main"

  # Pure bash + awk/sed/find, all present in the macOS base system. The optional
  # `config` subcommand additionally uses python3, detected at runtime.

  def install
    bin.install "bin/claude-clean"
  end

  def caveats
    <<~EOS
      Start with a read-only audit of your Claude Code install:

        claude-clean audit

      Deactivating skills MOVES them to ~/.claude/skills.disabled and never
      deletes them. Restart Claude Code for changes to take effect.
    EOS
  end

  test do
    assert_match "claude-clean #{version}", shell_output("#{bin}/claude-clean --version")
    assert_match "USAGE", shell_output("#{bin}/claude-clean --help")

    # Missing Claude Code install must fail loudly rather than silently.
    out = shell_output("CLAUDE_HOME=#{testpath}/absent #{bin}/claude-clean audit 2>&1", 1)
    assert_match "no Claude Code directory", out

    # Audit a synthetic install and confirm the skill is counted.
    (testpath/"home/skills/demo").mkpath
    (testpath/"home/skills/demo/SKILL.md").write <<~SKILL
      ---
      name: demo
      description: A demo skill used by the formula test.
      ---
      body
    SKILL
    out = shell_output("CLAUDE_HOME=#{testpath}/home NO_COLOR=1 #{bin}/claude-clean audit")
    assert_match "active skills", out
    assert_match "1", out
  end
end
