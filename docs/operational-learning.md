# Operational Learning System

Documentation for the framework's learning capture and injection system.

## Overview

The operational learning system captures project-specific knowledge across sessions, preventing agents from rediscovering the same quirks, conventions, and gotchas. When an agent discovers something non-obvious during a session, it records the discovery. Future sessions load recent learnings as context so that knowledge persists.

## How It Works

Three-phase lifecycle:

1. **During a session**: Agents run `hooks/learn.sh` when they discover non-obvious patterns. Each learning is appended to a temporary buffer file in `/tmp/`.
2. **Session end**: The `session-end.sh` hook collects all buffer files, appends their contents to the persistent JSONL file, prunes to 50 entries, and deletes the buffers.
3. **Next session start**: The `session-start.sh` hook reads the last 10 learnings from the persistent JSONL file and injects them into the session context.

## Recording a Learning

### Via slash command

The simplest method. Use `/learn` with a description:

```
/learn the auth service requires X-Request-ID header for all endpoints
```

If no argument is provided, the command will ask what you learned. The default category is `convention`.

### Via agent (automated)

Agents with learning capability automatically record non-obvious discoveries during their work:

```bash
"${CLAUDE_PLUGIN_ROOT}/hooks/learn.sh" "auth service requires X-Request-ID" "convention"
```

### Via direct script

Call the learning script directly from the command line:

```bash
./hooks/learn.sh "MySQL connection pool needs max 25 connections due to RDS limits" "gotcha"
./hooks/learn.sh "use make lint instead of golangci-lint directly" "tool"
```

Usage:

```
learn.sh <learning> [category]
```

- `learning` (required): Description of what was discovered
- `category` (optional): One of `convention`, `gotcha`, `pattern`, `tool`. Default: `convention`

## JSONL Format

Each learning is one line of JSON, stored in a JSONL file:

```json
{"learning":"auth service requires X-Request-ID header","category":"convention","timestamp":"2026-04-07T14:30:00Z"}
```

Fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `learning` | string | yes | What was discovered |
| `category` | string | no | One of `convention`, `gotcha`, `pattern`, `tool` (default: `convention`) |
| `timestamp` | string | no | ISO 8601 UTC timestamp, set automatically by `learn.sh` |

## Categories

| Category | Use When | Example |
|----------|----------|---------|
| `convention` | Project follows a non-obvious convention | "All HTTP handlers return domain errors, mapping happens in middleware" |
| `gotcha` | Something surprising that caused or could cause bugs | "MySQL driver silently truncates strings >255 chars in the name column" |
| `pattern` | A recurring code pattern specific to this project | "All repositories use the sqlx.DB wrapper from internal/db, not raw sqlx" |
| `tool` | Tool configuration or usage specific to this project | "golangci-lint must run with --build-tags=integration for full coverage" |

## Storage

| Location | Purpose | Lifecycle |
|----------|---------|-----------|
| `/tmp/claude-learnings-{project-slug}-{pid}` | Temporary buffer, one per session | Created during session, deleted by `session-end.sh` |
| `~/.claude-resources/learnings/{project-slug}.jsonl` | Persistent storage | Survives across sessions, pruned to 50 entries |

- **Project slug**: Derived from the git repository root basename (`basename $(git rev-parse --show-toplevel)`) or the working directory name if not in a git repo.
- **Buffer file PID**: Each buffer file includes the process ID (`$$`) to prevent collisions between concurrent sessions.
- **Retention**: The persistent JSONL file is pruned to the last 50 learnings on every session end. Older entries are dropped automatically.

## Session Lifecycle

### Session start (`session-start.sh`)

Triggered by the `SessionStart` hook registered in `hooks/hooks.json`. The script:

1. Detects project languages from marker files (`go.mod`, `package.json`, etc.)
2. Lists available core and language skills
3. Reads the last 10 learnings from `~/.claude-resources/learnings/{project-slug}.jsonl`
4. Parses each JSONL line using pure bash (sed extraction) to read the `learning` field — malformed lines are skipped silently
5. Injects all context (languages, skills, learnings, style guidance) as a JSON object into the session

### During session

Agents call `hooks/learn.sh` whenever they discover something non-obvious. Each call appends one JSONL line to `/tmp/claude-learnings-{project-slug}-{pid}`. Multiple learnings can accumulate in the same buffer file during a session.

### Session end (`session-end.sh`)

Triggered by the `SessionEnd` hook. The script:

1. Finds all buffer files matching `/tmp/claude-learnings-{project-slug}-*`
2. Appends their contents to `~/.claude-resources/learnings/{project-slug}.jsonl`
3. Deletes the buffer files
4. If the JSONL file exceeds 50 lines, prunes it to the last 50 entries

## What to Record

Record things a future session would waste time rediscovering:

- Unusual project conventions not obvious from the code (e.g., "error types live in internal/errors, not alongside the packages that use them")
- Gotchas that caused debugging time (e.g., "the test database must be reset between integration test suites")
- Non-obvious tool configuration requirements (e.g., "golangci-lint needs --build-tags=integration")
- Project-specific patterns that differ from standard practices (e.g., "all repositories implement the same 4-method interface defined in internal/repo")

## What NOT to Record

- Things obvious from reading the code or git history
- Standard language idioms (Go error handling patterns, Python virtual environments, etc.)
- Temporary debugging notes or one-off observations
- Personal preferences that do not affect project correctness
- Information already documented in the project's `CLAUDE.md` or README

## Troubleshooting

### Learnings not appearing in new sessions

1. **Check the directory exists**: `ls ~/.claude-resources/learnings/`
2. **Verify the project slug matches**: `basename $(git rev-parse --show-toplevel)` -- this must match between the session that wrote the learning and the session reading it
3. **Check the JSONL file has valid JSON lines**: `cat ~/.claude-resources/learnings/{slug}.jsonl` -- each line must be valid JSON
4. **Confirm bash version**: Both `learn.sh` and `session-start.sh` use pure bash for JSONL encoding and parsing (bash 4+ required for associative arrays and parameter-expansion features). No python or other runtime is needed.

### Buffer files accumulating in /tmp

The `session-end.sh` hook should clean these up automatically at session end. If buffers persist:

- The session may have ended abnormally without triggering the hook
- Manual cleanup: `rm /tmp/claude-learnings-*`

### Too many stale learnings

If the persistent file has accumulated outdated or incorrect learnings:

- **Edit directly**: Open `~/.claude-resources/learnings/{slug}.jsonl` and remove unwanted lines
- **Start fresh**: Delete the file entirely: `rm ~/.claude-resources/learnings/{slug}.jsonl`
- **Prune**: Keep only the most recent entries by editing the file

### Learning not recorded

If `learn.sh` runs without error but the learning does not appear:

- Check that the category is valid: must be one of `convention`, `gotcha`, `pattern`, `tool`
- Verify the buffer file was created: `ls /tmp/claude-learnings-*`
- Ensure the learning text is not empty (the script rejects empty strings)

For broader troubleshooting of hook failures, language detection, or session context issues, see [troubleshooting.md](troubleshooting.md).
