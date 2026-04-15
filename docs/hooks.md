# Hooks and Validators

Reference for the shell scripts under `hooks/`.

The framework uses two kinds of scripts:

1. **Lifecycle hooks** — triggered automatically by Claude Code's session events. Registered in `hooks/hooks.json`.
2. **Validator scripts** — run manually or in CI. They enforce plumbing integrity.

All hooks are pure bash (bash 4+). No python, no other runtime.

## Lifecycle hooks

### session-start.sh

**Fires on:** `SessionStart` event (registered in `hooks/hooks.json`)

**What it does:**

1. Detects project languages from marker files in the current working directory (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `angular.json`)
2. Lists available core skills from `skills/core/`
3. Lists available language skills for detected languages
4. Detects whether `skills/ops/` is populated (for the opt-in ops plugin)
5. Reads the last 10 operational learnings from `~/.claude-resources/learnings/{project-slug}.jsonl`
6. Checks for recommended exploration tools (`ast-grep`)
7. Emits a single JSON object to stdout, which Claude Code injects into the session context

**Output schema:**

```json
{
  "priority": "IMPORTANT",
  "detected_languages": "go",
  "core_skills": "api-design,code-review,...",
  "language_skills": "go: [api-design,cli,...]",
  "ops_enabled": true,
  "ops_skills": "git-remote,pull-requests,release,registry",
  "tools_warning": "Missing recommended tools: ast-grep. See README for setup.",
  "recent_learnings": "learning 1; learning 2; ...",
  "style": "Apply core/token-efficiency (standard) to human-facing output only. ...",
  "external_writes_policy": "Agents MUST check ops_enabled before executing any remote-write command..."
}
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `priority` | string | Always `IMPORTANT` — signals high-value context |
| `detected_languages` | string | Space-separated language codes |
| `core_skills` | string | Comma-separated core skill directory names |
| `language_skills` | string | Per-language skill lists |
| `ops_enabled` | boolean | `true` if `skills/ops/` is populated, else `false` |
| `ops_skills` | string | Comma-separated ops skill names (empty if `ops_enabled=false`) |
| `tools_warning` | string | Optional warning about missing recommended tools |
| `recent_learnings` | string | Semicolon-joined learning texts from the last 10 JSONL entries |
| `style` | string | Token-efficiency reminder loaded by every agent |
| `external_writes_policy` | string | Instruction for agents to check `ops_enabled` before remote writes |

**Known limitations:**

- Assumes bash 4+ (uses associative arrays and parameter expansion features)
- Malformed JSONL lines in the learnings file are silently skipped
- Language detection runs from the current working directory, not from the project root — the caller is responsible for `cd`-ing into the project

### session-end.sh

**Fires on:** `SessionEnd` event

**What it does:**

1. Reads all buffer files matching `/tmp/claude-learnings-{project-slug}-*`
2. Appends their contents to `~/.claude-resources/learnings/{project-slug}.jsonl`
3. Deletes the buffer files
4. If the persistent JSONL file exceeds 50 lines, prunes it to the last 50 entries

**No output.** Runs silently.

**Known limitations:**

- If the session ends abnormally (crash, kill), buffer files may persist in `/tmp/` until manually cleaned
- 50-line retention is hard-coded; increase by editing the script

### learn.sh

**Fires on:** Manual invocation, either from the `/learn` slash command or directly by an agent via `${CLAUDE_PLUGIN_ROOT}/hooks/learn.sh`.

**What it does:**

1. Validates arguments: learning text (required), category (optional, default `convention`)
2. Rejects categories outside `convention`, `gotcha`, `pattern`, `tool`
3. Resolves the project slug from the git root basename (falls back to `pwd`)
4. Writes one JSONL line to `/tmp/claude-learnings-{project-slug}-{pid}`:

```json
{"learning":"...","category":"...","timestamp":"2026-04-15T12:00:00Z"}
```

5. Prints a confirmation line to stdout

**Usage:**

```bash
./hooks/learn.sh "auth service requires X-Request-ID header"
./hooks/learn.sh "MySQL driver truncates strings >255 chars" "gotcha"
./hooks/learn.sh "use make lint instead of golangci-lint directly" "tool"
```

See [operational-learning.md](operational-learning.md) for the full lifecycle (when to record, what to record, how it surfaces in future sessions).

## Validator scripts

All validators run with zero arguments. Exit code 0 means pass, non-zero means fail. Run them individually or use the `validate-all.sh` wrapper.

### validate-marketplace.sh

**What it checks:** Every skill path listed in `.claude-plugin/marketplace.json` must resolve to a directory containing a `SKILL.md` file.

**How to run:**

```bash
hooks/validate-marketplace.sh
```

**Exit codes:**

- `0` — all skill paths resolve
- `1` — at least one path is broken
- `2` — marketplace.json is missing or contains no skill paths

**Typical failures:**

- A skill directory was renamed but `marketplace.json` still references the old path
- A new skill path was added to `marketplace.json` before the `SKILL.md` file was created (strict-mode violation)

**Fix:** match the path in `marketplace.json` to the actual directory, or create the missing `SKILL.md`.

### validate-skill-anatomy.sh

**What it checks:** Every skill in `skills/core/` and `skills/ops/` must contain the five required sections: `## When to Use`, `## When NOT to Use`, `## Common Rationalizations`, `## Red Flags`, `## Verification`.

Meta-skills can opt out by including the exact line `<!-- meta-skill: skip-anatomy -->` anywhere in the file.

**How to run:**

```bash
hooks/validate-skill-anatomy.sh
```

**Exit codes:**

- `0` — all skills pass
- `1` — at least one skill is missing a required section
- `2` — no tier directories found

**Typical failures:**

- A new skill was written without one of the required sections
- A section was renamed or reformatted in a way the grep cannot match (exact heading text is required)

**Fix:** add the missing section using the exact heading text, or add the skip-anatomy marker if the file is a meta-skill.

### validate-skill-references.sh

**What it checks:** Every skill listed in an agent's `skills:` frontmatter must resolve to a directory containing a `SKILL.md`.

**How to run:**

```bash
hooks/validate-skill-references.sh
```

**Exit codes:**

- `0` — all references resolve
- `1` — at least one broken reference
- `2` — `agents/` directory is missing

**Typical failures:**

- A skill was renamed but an agent's frontmatter still references the old name
- Typo in an agent's skill list

**Fix:** match the reference to the actual skill path.

### validate-agents.sh

**What it checks:** Every agent name referenced in `.claude/commands/*.md` must resolve to an agent file in `agents/` by the frontmatter `name:` field.

Also flags any leftover `{plugin}:{lang}-*` template strings in command files.

**How to run:**

```bash
hooks/validate-agents.sh
```

**Exit codes:**

- `0` — all command → agent references resolve
- `1` — at least one broken reference, or an unresolved template string
- `2` — `commands/` or `agents/` directory is missing

**Typical failures:**

- A command spawns an agent by a name that does not exist in `agents/`
- An old-style `{plugin}:{lang}-*` template was left in a command file

**Fix:** update the command to use the correct bare agent name (e.g., `reviewer`, not `{plugin}:{lang}-reviewer`).

### validate-all.sh

**What it does:** Runs all four validators in sequence. Reports the total number that failed. Exit code is 1 if any validator fails, 0 if all pass.

**How to run:**

```bash
hooks/validate-all.sh
```

Recommended before every commit. Not wired as a git pre-commit hook — keep it opt-in so contributors choose when to enforce it.

## Running the validators in CI

Example CI step:

```bash
chmod +x hooks/*.sh
hooks/validate-all.sh
```

If any validator fails, CI fails. All four are idempotent and side-effect-free — they only read files.
