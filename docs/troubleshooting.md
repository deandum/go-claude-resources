# Troubleshooting

Consolidated troubleshooting for common issues. Grouped by symptom.

If your issue is not listed here, check [getting-started.md](getting-started.md), [hooks.md](hooks.md), or [operational-learning.md](operational-learning.md) for topic-specific troubleshooting.

## Language not detected

**Symptom:** Agents do not load Go (or Python, Rust, Node, Angular) skills even though the project is clearly a project of that type.

**Diagnosis:** `session-start.sh` looks for marker files in the **current working directory**. If Claude Code started from a parent directory, the markers may be missing.

**Fix:**

1. Check that marker files exist in the expected location:
   - Go: `go.mod`
   - Node: `package.json` (no `angular.json`)
   - Angular: `package.json` + `angular.json`
   - Rust: `Cargo.toml`
   - Python: `pyproject.toml` or `requirements.txt`
2. Run `hooks/session-start.sh` manually from the project root and inspect the JSON output — check the `detected_languages` field.
3. If the marker file exists but detection fails, confirm the file is at the project root, not nested inside a subdirectory.

## Skills not loading

**Symptom:** An agent does not have a skill loaded that you expected.

**Diagnosis:** Either the skill is not registered in `marketplace.json`, or the agent's `skills:` frontmatter does not include it.

**Fix:**

1. Verify the skill is registered:
   ```bash
   grep "my-skill" .claude-plugin/marketplace.json
   ```
2. Verify the agent's frontmatter includes it:
   ```bash
   grep "my-skill" agents/*.md
   ```
3. Run `hooks/validate-skill-references.sh` to confirm all agent references resolve.
4. If the skill is a language-specific one, confirm the language was detected (see "Language not detected" above).

## Hooks not running

**Symptom:** The session-start or session-end hook never fires. No session context is injected. No learnings are persisted.

**Diagnosis:** The hook registration file may be malformed, or the scripts may not be executable.

**Fix:**

1. Check `hooks/hooks.json` is valid JSON:
   ```bash
   python3 -m json.tool hooks/hooks.json
   ```
2. Confirm the scripts are executable:
   ```bash
   ls -la hooks/*.sh
   chmod +x hooks/*.sh
   ```
3. Confirm the `$CLAUDE_PLUGIN_ROOT` environment variable is set at hook execution time. The hook commands in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh` — if that variable is empty, the path will not resolve.
4. Test manually:
   ```bash
   hooks/session-start.sh
   ```
   If it prints JSON, the script works. If it errors, read the error message.

## Session context not appearing

**Symptom:** `session-start.sh` runs but no context shows up in the agent's view.

**Diagnosis:** Claude Code injects hook output into context on session start. If the output is malformed JSON, the injection may be silently dropped.

**Fix:**

1. Run the hook directly and pipe to a JSON validator:
   ```bash
   hooks/session-start.sh | python3 -m json.tool
   ```
2. If the output is not valid JSON, inspect the script for escaping issues (especially with learning text containing quotes or newlines).
3. Confirm the `session-start.sh` was updated to pure bash — the old python3-based version would fail silently if python3 was missing.

## Learnings not appearing in new sessions

**Symptom:** You recorded learnings in a previous session but they do not surface in a new session.

**Diagnosis:** Several possible causes.

**Fix:**

1. Check the persistent file exists:
   ```bash
   ls ~/.claude-resources/learnings/
   ```
2. Verify the project slug matches — it must be identical between the session that wrote the learning and the session reading it:
   ```bash
   basename "$(git rev-parse --show-toplevel)"
   ```
3. Check the JSONL file contains valid lines:
   ```bash
   cat ~/.claude-resources/learnings/<project-slug>.jsonl
   ```
   Each line must be valid JSON with a `learning` field.
4. Confirm bash 4+ is available (`bash --version`) — older versions lack the parameter-expansion features `session-start.sh` uses.

See [operational-learning.md](operational-learning.md) for the full learning lifecycle.

## Validator errors

### validate-marketplace: skill path broken

**Diagnosis:** A path in `marketplace.json` does not resolve to a directory with a `SKILL.md`.

**Fix:** Either create the missing `SKILL.md` at that path, or update the path in `marketplace.json` to the actual location. Remember the marketplace is `strict: true` — any missing path breaks the whole plugin install.

### validate-skill-anatomy: missing section

**Diagnosis:** A core or ops skill is missing one of the five required sections.

**Fix:** Add the missing section with the exact heading text. The validator does a literal string match — `## When to Use` works, `## When to use` (lowercase `u`) does not. For meta-skills that legitimately cannot follow the anatomy (e.g., `skill-discovery`), add the marker line `<!-- meta-skill: skip-anatomy -->` anywhere in the file.

### validate-skill-references: missing skill

**Diagnosis:** An agent's `skills:` frontmatter references a skill that does not exist.

**Fix:** Check for typos. Verify the referenced path (e.g., `core/my-skill` → `skills/core/my-skill/SKILL.md`) exists.

### validate-agents: unknown agent

**Diagnosis:** A slash command spawns an agent by a name that does not resolve to any file in `agents/`.

**Fix:** Update the command to use the correct bare agent name (e.g., `reviewer`, `builder`). If you see `{plugin}:{lang}-*` template strings, replace them with the bare agent name — those templates are leftovers from an earlier design and do not resolve.

## Agent not found when running a command

**Symptom:** A slash command runs but Claude Code cannot find the agent it tried to spawn.

**Diagnosis:** Either the command file references a wrong agent name, or the agent's `name:` frontmatter field does not match.

**Fix:**

1. Read the command file and note the agent name it tries to spawn.
2. Check that `agents/<name>.md` exists and that its frontmatter has the matching `name:` field.
3. Run `hooks/validate-agents.sh` to confirm all command → agent references resolve.
4. Confirm the agent's file does not contain leftover template strings in tools or skills fields.

## SPEC file not generated

**Symptom:** You ran `/define` but no `SPEC-*.md` file was created.

**Diagnosis:** The `lead` agent may have failed during the critic handoff or the spec generation step.

**Fix:**

1. Check the agent's output for error messages.
2. Confirm the user provided a clear task description — if too vague, the critic may have returned a "needs more input" response rather than proceeding to spec generation.
3. Confirm the user approved the spec when prompted — lead does not write the file to disk unless approval is explicit.
4. Check that `lead` has the `Write` tool in its frontmatter (it should; if not, that is the bug).

## ops_enabled false when expected to be true

**Symptom:** You installed the `ops-skills` plugin but `ops_enabled` in session context is `false`.

**Diagnosis:** `session-start.sh` checks whether `skills/ops/` exists and contains at least one skill directory. If the check fails, `ops_enabled` is `false`.

**Fix:**

1. Confirm the directory exists:
   ```bash
   ls skills/ops/
   ```
2. Confirm it contains skill directories (not just empty or hidden files):
   ```bash
   find skills/ops -mindepth 1 -maxdepth 1 -type d
   ```
3. Re-run the hook and check the output:
   ```bash
   hooks/session-start.sh | grep ops_enabled
   ```
4. Restart the Claude Code session — the hook runs on session start, so changes to the file system are not picked up mid-session.

See [ops-skills.md](ops-skills.md) for installation details.

## Plugin install failures

**Symptom:** `claude plugin add` fails or the plugin appears to install but skills do not load.

**Diagnosis:** The marketplace is `strict: true` — any missing skill path in `marketplace.json` breaks the whole plugin install.

**Fix:**

1. Run `hooks/validate-marketplace.sh` locally to check for broken paths.
2. If a path is broken, the plugin cannot install cleanly.
3. After fixing paths, re-run `claude plugin add`.

## Buffer files accumulating in /tmp

**Symptom:** Files matching `/tmp/claude-learnings-*` are piling up.

**Diagnosis:** The `session-end.sh` hook should clean these up on every session end. If buffers persist, the hook is not running on session end (crash, kill, abnormal exit), or the project slug changed between sessions.

**Fix:**

1. Confirm `session-end.sh` runs on session end — check `hooks/hooks.json` for the SessionEnd registration.
2. Manually clean up:
   ```bash
   rm /tmp/claude-learnings-*
   ```
3. If buffers accumulate regularly, add a cron job or a login-shell cleanup script as a fallback.

## Getting more help

- For workflow questions, read [workflow.md](workflow.md).
- For skill authoring, read [skill-anatomy.md](skill-anatomy.md).
- For architecture questions, read [architecture.md](architecture.md).
- For extension questions (adding skills, agents, commands), read [extending.md](extending.md).
