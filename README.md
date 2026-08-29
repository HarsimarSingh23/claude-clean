# claude-clean

**Your Claude Code session starts at 40% context used. Here's why, and how to fix it.**

`claude-clean` audits and reduces the context Claude Code burns before you type
a single word — and reclaims the disk it quietly accumulates.

```
$ claude-clean audit

Startup context (paid on every request)
  active skills                      1137
  deactivated skills                 0
    skill names                      ~6054 tokens
    skill descriptions               ~45568 tokens
    metadata total                   ~51622 tokens
    share of context                 25.8% of a 200k window
```

```
$ claude-clean skills --keep-used

Deactivated 957 skills.
  startup metadata: ~51869 -> ~8232 tokens (saved ~43637, 21.8% of a 200k window)
```

---

## The problem

Claude Code is a **stateless LLM in a loop**. There is no persistent session
memory on the model side — every single turn, the entire context is rebuilt from
scratch and re-sent:

```
[ system prompt + environment ]   fixed
[ tool schemas ]                  every tool's full JSON schema
[ MCP server tools ]              schemas from every connected MCP server
[ skill metadata ]                name + description of EVERY installed skill
[ CLAUDE.md files ]               global + project memory
[ conversation so far ]           grows each turn
```

Everything above the last line is **fixed overhead** — paid on every request,
for the whole session.

The expensive part is subtle. **Skills are lazy-loaded in body, but
eager-loaded in metadata.** A skill's `SKILL.md` body only enters context when
you invoke it. But its `name` and `description` frontmatter is injected at
startup for *every installed skill*, so the model knows what's available.

1,000 installed skills = 1,000 descriptions in your prompt before you say hello.

Install a skill marketplace in bulk and you can hand 25%+ of your context window
to skills you will never use. On the install that motivated this tool: **1,137
skills costing ~51,600 tokens, of which 4 had ever been invoked.**

## What claude-clean does

Measures that overhead honestly, then lets you cut it **reversibly**.

Deactivating a skill **moves** its directory to `~/.claude/skills.disabled`.
Claude Code only scans `~/.claude/skills`, so the skill leaves your context
while staying on your disk, assets and all. One command brings it back.

| Command | Affects context? | Reversible? |
|---|---|---|
| `skills` — deactivate / reactivate skills | **Yes — this is the big one** | Yes, moved to `skills.disabled` |
| `cache` — telemetry, shell snapshots, old backups | No | No, but all regenerable |
| `config` — strip `cached*` keys from `~/.claude.json` | No | Yes, backed up first |
| `transcripts` — old `*.jsonl` session logs | No (only on `--resume`) | **No — destructive** |

Two things people commonly get wrong, which this tool is careful about:

- **`~/.claude/projects` is not your context problem.** Session transcripts are
  often the largest thing on disk (93 MB in the motivating case) but cost
  **zero** startup context — they only load on `--resume` / `--continue`. Clean
  them for disk, not for tokens.
- **Transcript deletion is the only destructive operation here**, so it is
  deliberately excluded from `claude-clean all` and always prompts.

## Install

### Homebrew

```bash
brew tap HarsimarSingh23/claude-clean
brew trust HarsimarSingh23/claude-clean   # Homebrew 6+ requires trusting third-party taps
brew install claude-clean
```

### Homebrew, from a checkout (no GitHub needed)

```bash
git clone https://github.com/HarsimarSingh23/claude-clean
cd claude-clean
./scripts/install-local-tap.sh
```

### Plain install

```bash
install -m 0755 bin/claude-clean /usr/local/bin/claude-clean
```

No runtime dependencies: bash plus `awk`/`sed`/`find` from the base system.
The optional `config` subcommand additionally uses `python3`, detected at
runtime.

## Usage

```
claude-clean <command> [options]

  audit                       Measure startup context + disk usage  (default)
  skills [opts]               Manage which skills load into context
  cache [opts]                Purge telemetry, shell snapshots, old backups
  transcripts [opts]          Prune old session transcripts (disk only)
  config                      Strip regenerable cache keys from ~/.claude.json
  keep [show|init|add ...]    Manage the never-deactivate skill list
  all                         audit + cache + config
```

### `skills`

```
--list                Show active and deactivated skills
--top [N]             Rank active skills by description token cost
--keep-used           Deactivate every skill you have never invoked
--keep a,b,c          Extra names to preserve alongside --keep-used
--strict              Honor only the keep-file/--keep list; ignore usage history
--match REGEX         Deactivate active skills matching a regex
--disable <name>...   Deactivate specific skills
--enable  <name>...   Reactivate specific skills
--enable-all          Reactivate everything
```

### Global flags

```
-n, --dry-run    Show what would happen, change nothing
-y, --yes        Skip confirmation prompts
-q, --quiet      Suppress informational output
```

### Environment

```
CLAUDE_HOME     default ~/.claude
CLAUDE_CONFIG   default ~/.claude.json
NO_COLOR        disable colored output
```

## Recipes

**Look before you touch anything:**

```bash
claude-clean audit
claude-clean skills --top 30
```

**Keep only what you've actually used:**

```bash
claude-clean skills --keep-used --dry-run   # preview
claude-clean skills --keep-used             # apply
```

`--keep-used` reads `skillUsage` from `~/.claude.json` — the skills Claude Code
records you having actually invoked.

**Curate by role.** Usage history is a weak signal if you have just installed a
marketplace. Write `~/.claude/claude-clean.keep` — one skill name per line, `#`
comments allowed — then:

```bash
claude-clean skills --keep-used --strict
```

`--strict` makes the keep-file the whole truth: skills you happened to invoke
once are *not* silently preserved. Seed a starting point from your history with
`claude-clean keep init`.

**Reclaim disk:**

```bash
claude-clean cache -y                     # telemetry, stale snapshots, old backups
claude-clean transcripts --older-than 60  # prompts; destructive
```

**Undo everything:**

```bash
claude-clean skills --enable-all
```

> Restart Claude Code after any skill change — the prompt is assembled at
> session start.

## Notes on accuracy

- Token figures are estimates at ~4 chars/token. Use them for **relative
  comparison**, not billing. The ratios are what matter.
- Skill discovery is **case-insensitive** (`SKILL.md` / `skill.md`). Some
  marketplace skills ship lowercase, and a case-sensitive `find` silently
  undercounts them on macOS's case-insensitive filesystem.
- YAML folded/wrapped `description:` blocks are measured including their
  continuation lines.
- Deactivation moves the **whole skill directory**, so references, scripts, and
  assets travel with it.

## Development

```bash
bash -n bin/claude-clean   # syntax check
shellcheck bin/claude-clean
```

The Homebrew formula lives in a **separate tap repo**
([HarsimarSingh23/homebrew-claude-clean](https://github.com/HarsimarSingh23/homebrew-claude-clean)),
generated from [`packaging/claude-clean.rb.tmpl`](packaging/claude-clean.rb.tmpl).

It is kept out of this repo on purpose. A formula stored inside the tarball it
checksums is self-referential: editing the formula changes the tarball, which
changes the `sha256`, which requires editing the formula. Related trap — GitHub
caches release archives per tag name, so **moving or reusing a tag can serve a
stale tarball** and break a published checksum. `release.sh` always cuts a fresh
tag.

Test against a synthetic install rather than your real one:

```bash
export CLAUDE_HOME=/tmp/fake-claude CLAUDE_CONFIG=/tmp/fake-claude/.claude.json
mkdir -p "$CLAUDE_HOME/skills/demo"
printf -- '---\nname: demo\ndescription: test\n---\nbody\n' > "$CLAUDE_HOME/skills/demo/SKILL.md"
claude-clean audit
```

### Releasing

```bash
scripts/release.sh 1.0.2
```

Stamps the version, pushes, cuts a fresh tag and GitHub release, computes the
tarball checksum, then renders and pushes the formula to the tap.

## Contributing

Issues and PRs welcome. This is deliberately a single dependency-free bash
script — please keep it that way. If you add a subcommand, add its assertions to
the `test do` block in `packaging/claude-clean.rb.tmpl`.

## License

MIT — see [LICENSE](LICENSE).
