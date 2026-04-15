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
3. If the skill is a language-specific one, confirm the language was detected (see "Language not detected" above).

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

## Agent not found when running a command

**Symptom:** A slash command runs but Claude Code cannot find the agent it tried to spawn.

**Diagnosis:** Either the command file references a wrong agent name, or the agent's `name:` frontmatter field does not match.

**Fix:**

1. Read the command file and note the agent name it tries to spawn.
2. Check that `agents/<name>.md` exists and that its frontmatter has the matching `name:` field.
3. Confirm the agent's file does not contain leftover template strings in tools or skills fields.

## Spec directory not generated

**Symptom:** You ran `/define` but no `docs/specs/<slug>/` directory was created.

**Diagnosis:** The `lead` agent may have failed during the critic + scout handoff or the spec generation step.

**Fix:**

1. Check the agent's output for error messages from critic or scout.
2. Confirm the user provided a clear task description — if too vague, critic may have returned `needs-input` rather than proceeding to spec generation.
3. Confirm both critic AND scout ran — lead MUST spawn them in parallel, not sequentially.
4. Confirm the user approved the spec when prompted — lead does not finalize the directory unless Group 0 sign-off is explicit.
5. Check that `lead` has the `Write` tool in its frontmatter (it should; if not, that is the bug).
6. Confirm the template files exist at `skills/core/spec-generation/references/` — lead copies them into place.

## Active specs not surfacing on session start

**Symptom:** A spec is in progress (`status: in-progress`) but `session-start.sh` is not listing it in `active_specs`.

**Diagnosis:** Either the spec frontmatter is malformed, the session-start hook cannot read the spec file, or the directory is not under `docs/specs/`.

**Fix:**

1. Run the hook manually and inspect the JSON:
   ```bash
   hooks/session-start.sh | python3 -m json.tool
   ```
2. Check the spec's frontmatter fields:
   ```bash
   head -20 docs/specs/<slug>/spec.md
   ```
   Required: `task`, `status`, `current_group`, `total_groups`.
3. Confirm `status` is not `complete` — completed specs are intentionally excluded from `active_specs`.

## current_group drifts from group-log.md

**Symptom:** `spec.md` frontmatter `current_group` does not match the last `## Group N` heading in `group-log.md`.

**Diagnosis:** A session crashed or was killed between writing to `group-log.md` and updating `spec.md` frontmatter.

**Fix:**

1. Read `docs/specs/<slug>/group-log.md` and find the last `## Group N` heading.
2. If the last group completed and the user approved it but frontmatter was not updated: set `current_group: N+1` in `spec.md`.
3. If the group was in progress and the session crashed: set `current_group: N` and re-run the group via `/orchestrate --resume <slug>`.
4. When in doubt, trust `group-log.md` — it is append-only and more reliable than frontmatter.

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

1. Inspect `.claude-plugin/marketplace.json` and confirm every `./skills/...` entry resolves to a directory containing `SKILL.md`.
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
