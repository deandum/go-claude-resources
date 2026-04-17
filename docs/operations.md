# Operations

How the framework runs at the session level: lifecycle hooks, the operational learning system, and the opt-in ops plugin for external-write actions. Everything in this doc is about runtime behavior, not authoring content.

## Lifecycle hooks

Three bash scripts under `hooks/`. Two are registered in `hooks/hooks.json` and fire on Claude Code lifecycle events; one is called manually.

All hooks are pure bash (bash 4+). No python, no other runtime. Shared helpers live in `hooks/lib/common.sh` and are sourced idempotently.

### session-start.sh

**Fires on:** `SessionStart` event.

**What it does:**

1. Detects project languages from marker files at the project root (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `angular.json`) — resolved via `git rev-parse --show-toplevel`, falling back to `pwd`. Works correctly when Claude is launched from any subdirectory.
2. Lists available core skills and language skills for detected languages.
3. Detects whether `skills/ops/` is populated (opt-in ops plugin — see below).
4. Reads the last 10 operational learnings from `~/.claude-resources/learnings/{project-slug}.jsonl`.
5. Scans `docs/specs/*/spec.md` for in-progress specs (`status != complete`) and emits `active_specs` with `current_group`/`total_groups`.
6. Probes third-party integrations: 8 known CLI tools, MCP servers from `~/.claude.json` / `./.mcp.json`, user-scope skills / agents / plugins under `~/.claude/`.
7. Emits a single JSON object to stdout. Claude Code injects it into session context.

**Output schema:**

```json
{
  "priority": "IMPORTANT",
  "detected_languages": "go",
  "core_skills": "api-design,code-review,...",
  "language_skills": "go: [api-design,cli,...]",
  "ops_enabled": true,
  "ops_skills": "git-remote,pull-requests,release,registry",
  "available_tools": "jq,rg,gh,docker",
  "missing_tools": "ast-grep,fd,yq,kubectl",
  "mcp_servers": "playwright,magic,memory",
  "user_skills": "",
  "user_agents": "",
  "user_plugins": "claude-code-workflows,code-review-ai",
  "recent_learnings": "learning 1; learning 2; ...",
  "active_specs": "rate-limiter:2/4, cache-refactor:0/3",
  "external_writes_policy": "Agents MUST check ops_enabled before executing any remote-write command...",
  "spec_resumption_policy": "When active_specs is non-empty, main Claude surfaces the in-progress specs..."
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
| `available_tools` | string | CLI tools on PATH from the fixed probe list: `ast-grep`, `fd`, `rg`, `jq`, `yq`, `gh`, `docker`, `kubectl`. |
| `missing_tools` | string | Complement of `available_tools`. Agents use this to explain fallbacks, not to nag the user. |
| `mcp_servers` | string | MCP server names extracted from `~/.claude.json`, `~/.claude/settings.json`, `./.mcp.json`. Only names — never `command`/`args`/`env` (secret hygiene). Requires `jq`. |
| `user_skills` | string | Directory names under `~/.claude/skills/`. |
| `user_agents` | string | Directory names under `~/.claude/agents/`. |
| `user_plugins` | string | Plugin names from `~/.claude/plugins/installed_plugins.json`. |
| `recent_learnings` | string | Semicolon-joined learning texts from the last 10 JSONL entries. |
| `active_specs` | string | Comma-joined `<slug>:<current_group>/<total_groups>` tuples for in-progress specs. |
| `external_writes_policy` | string | Instruction for agents to check `ops_enabled` before remote writes. |
| `spec_resumption_policy` | string | Instruction for main Claude to surface `active_specs` on session start via `AskUserQuestion`. |

**Third-party discovery is observational.** The framework has zero hard dependency on any detected tool. Bare systems are fully supported. Agents read these fields to surface relevant options alongside the framework's native approach, never to gate behavior.

**Known limitations:**

- Malformed JSONL lines in the learnings file are silently skipped.
- MCP server discovery requires `jq` on PATH — without it, `mcp_servers` is empty and a one-line warning goes to stderr.

### session-end.sh

**Fires on:** `SessionEnd` event.

**What it does:**

1. Reads all buffer files matching `{buffer_dir}/{project-slug}-*` where `{buffer_dir}` is `${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-resources/buffers` (per-user, mode 700).
2. Appends their contents to `~/.claude-resources/learnings/{project-slug}.jsonl`.
3. Deletes the buffer files.
4. If the persistent JSONL file exceeds 50 lines, prunes it to the last 50.

The append-and-prune sequence runs under an advisory lock (`flock -x` when available, `mkdir`-based spinlock fallback with a 5-second timeout). This prevents concurrent session ends from losing entries.

**No stdout.** Warnings go to stderr.

**Known limitations:**

- If a session ends abnormally (crash, kill), buffer files may persist until the next session-end picks them up.
- 50-line retention is hard-coded; change by editing the script.

### learn.sh

**Fires on:** Manual invocation, either from the `/learn` slash command or directly by an agent via `${CLAUDE_PLUGIN_ROOT}/hooks/learn.sh`.

**What it does:**

1. Validates arguments: learning text (required), category (optional, default `convention`).
2. Rejects categories outside `convention`, `gotcha`, `pattern`, `tool`.
3. Resolves the project slug from the git root basename (falls back to `pwd`).
4. Writes one JSONL line (mode 600, via `umask 077`) to `{buffer_dir}/{project-slug}-{pid}`:

```json
{"learning":"...","category":"...","timestamp":"2026-04-15T12:00:00Z"}
```

5. Prints a confirmation line to stdout.

**Usage:**

```bash
./hooks/learn.sh "auth service requires X-Request-ID header"
./hooks/learn.sh "MySQL driver truncates strings >255 chars" "gotcha"
./hooks/learn.sh "use make lint instead of golangci-lint directly" "tool"
```

### Shared helpers (`hooks/lib/common.sh`)

Sourced by all three hook scripts. Exposes:

- `json_escape <string>` — escapes `\`, `"`, `\n`, `\r`, `\t` for safe emission inside a quoted JSON value.
- `project_root` — memoized `git rev-parse --show-toplevel || pwd`.
- `project_slug` — memoized `basename` of `project_root`.
- `buffer_dir` — resolves `${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-resources/buffers` and creates it with mode 700.
- `with_lock <file> <cmd...>` — runs `<cmd>` under an advisory lock (prefers `flock`, falls back to `mkdir`-spinlock).
- `list_subdirs <dir>` — lists immediate subdirectory basenames via bash parameter expansion.

Re-sourcing is a no-op (guarded by `_CLAUDE_HOOKS_COMMON_LOADED`).

## Learning system

The learning system captures project-specific knowledge across sessions so agents do not rediscover the same conventions, gotchas, and patterns. The hooks above are the mechanism; this section is the lifecycle.

### Three-phase lifecycle

1. **During a session**: agents run `hooks/learn.sh` when they discover non-obvious patterns. Each learning is appended to a per-user buffer file under `${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-resources/buffers/` with mode 600.
2. **Session end**: `session-end.sh` drains all buffer files into `~/.claude-resources/learnings/{project-slug}.jsonl`, prunes to 50 entries, and deletes the buffers. The drain-and-prune runs under an advisory lock.
3. **Next session start**: `session-start.sh` reads the last 10 learnings and injects them into the session context as `recent_learnings`.

### Recording a learning

Three equivalent entry points:

**Via slash command** (simplest):

```
/learn the auth service requires X-Request-ID header for all endpoints
```

If no argument is provided, the command asks. Default category is `convention`.

**Via agent (automated).** Agents with the `Bash` tool call `learn.sh` when they discover something non-obvious:

```bash
"${CLAUDE_PLUGIN_ROOT}/hooks/learn.sh" "auth service requires X-Request-ID" "convention"
```

**Via direct script:**

```bash
./hooks/learn.sh "<learning text>" [category]
```

### JSONL format

Each learning is one line:

```json
{"learning":"auth service requires X-Request-ID header","category":"convention","timestamp":"2026-04-07T14:30:00Z"}
```

| Field | Required | Description |
|---|---|---|
| `learning` | yes | What was discovered |
| `category` | no | `convention`, `gotcha`, `pattern`, or `tool` (default: `convention`) |
| `timestamp` | no | ISO 8601 UTC, set automatically |

### Categories

| Category | When to use | Example |
|---|---|---|
| `convention` | Project follows a non-obvious convention | "All HTTP handlers return domain errors; mapping happens in middleware" |
| `gotcha` | Something surprising that caused or could cause bugs | "MySQL driver silently truncates strings >255 chars in the name column" |
| `pattern` | Recurring code pattern specific to this project | "All repositories use the sqlx.DB wrapper from internal/db, not raw sqlx" |
| `tool` | Tool config or usage specific to this project | "golangci-lint must run with --build-tags=integration for full coverage" |

### Storage

| Location | Purpose | Lifecycle |
|---|---|---|
| `${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-resources/buffers/{project-slug}-{pid}` | Per-invocation buffer | Created during session (mode 600 under a mode-700 dir), drained by `session-end.sh`. |
| `~/.claude-resources/learnings/{project-slug}.jsonl` | Persistent storage | Survives sessions, pruned to 50 entries under an advisory lock. |

- **Project slug**: `basename $(git rev-parse --show-toplevel)`, or the working directory name if not in a git repo.
- **Per-user buffer dir**: under `$XDG_RUNTIME_DIR` when set (typical under systemd — tmpfs), otherwise `~/.cache`. Multi-tenant hosts cannot cross-contaminate.
- **Buffer PID suffix**: prevents collisions between concurrent `learn.sh` calls in the same session.
- **Retention**: persistent file pruned to the last 50 learnings on every session end.
- **Concurrency**: `session-end.sh` holds an advisory lock around drain-and-prune; concurrent sessions cannot lose entries.

### What to record

Record things a future session would waste time rediscovering:

- Non-obvious project conventions (e.g., "error types live in internal/errors, not alongside the packages that use them")
- Gotchas that cost debug time (e.g., "the test database must be reset between integration test suites")
- Non-obvious tool configuration requirements
- Project-specific patterns that differ from standard practices

### What NOT to record

- Things obvious from reading the code or git history
- Standard language idioms (Go error handling, Python virtualenvs, etc.)
- Temporary debugging notes or one-off observations
- Personal preferences that don't affect project correctness
- Information already documented in `CLAUDE.md` or README

## Ops plugin (opt-in)

The framework treats external-write actions — `git push`, `gh pr create`, `docker push`, release publishing — differently from local work. They live in a separate plugin that is **not enabled by default**. If the plugin is not installed, agents refuse to run those commands and report the intended action as a follow-up.

### Why external writes are separate

External writes have a larger blast radius than local changes:

- A push visible to collaborators
- A PR that triggers CI and notifies reviewers
- A release that downstream consumers will pull
- A container image that production will use

Some projects want Claude to handle these end-to-end. Others never want them to run without human review. The framework respects both by making the external-write skills a separate, opt-in plugin.

### What is in the plugin

Four skills, all under `skills/ops/`. See [reference.md](reference.md#ops-skills-4--opt-in) for the full table.

Each ops skill follows the same anatomy as a core skill. The "When NOT to Use" section of every ops skill starts with: *"Session context has `ops_enabled=false` — **do not push**, report the intended push as a follow-up instead."*

### How detection works

Automatic. `session-start.sh` checks whether `skills/ops/` exists and contains at least one skill directory:

- If yes → emits `ops_enabled: true` and lists the ops skills.
- If no → emits `ops_enabled: false` and `ops_skills: ""`.

The session context is visible to every agent. Code-writing agents check the flag before running any external-write command.

### Installation

```bash
# Via marketplace
claude plugin add ops-skills
```

Or, if working from a local clone, `skills/ops/` is already present — `session-start.sh` picks it up automatically.

Remove with `claude plugin remove ops-skills`, or simply delete/rename `skills/ops/`. The hook detects the change on the next session start.

### Agent guards

Three agents contain an "External Side Effects" section that enforces the gate:

- `builder`
- `cli-builder`
- `shipper`

Main Claude (running `core/orchestration`) also checks `ops_enabled` before planning any group that includes external writes. Each guard has the same structure:

1. Names the external-write actions (push, PR, release, registry, cloud deploy).
2. States the rule: run only when `ops_enabled=true`; report as follow-up when `false`.
3. References the relevant ops skill.
4. Concludes: *"If you are unsure whether an action is an external write, it probably is. Err on the side of reporting, not executing."*

Agents without the guard — `critic`, `reviewer`, `tester`, `architect` — do not perform external writes in the first place.

### Verify the plugin is installed

```bash
hooks/session-start.sh | jq '.ops_enabled, .ops_skills'
```

Output when enabled:

```
true
"git-remote,pull-requests,registry,release"
```

Output when disabled:

```
false
""
```

### What changes when the plugin is disabled

| Action | `ops_enabled=true` | `ops_enabled=false` (default) |
|---|---|---|
| `git push` | Runs, following `ops/git-remote` discipline | Reported as follow-up |
| `gh pr create` | Runs, following `ops/pull-requests` discipline | Reported as follow-up |
| Release publishing | Runs, following `ops/release` discipline | Reported as follow-up |
| `docker push` | Runs, following `ops/registry` discipline | Reported as follow-up |
| Local commits | Always runs | Always runs |
| Building a Docker image locally | Always runs | Always runs |
| Writing a SPEC file | Always runs | Always runs |
| Writing or modifying source code | Always runs | Always runs |

The gate is only on external writes. Everything local is unaffected.

### Soft vs hard gating

The current implementation is **soft gating**: agents cooperatively check `ops_enabled` and refuse to run external-write commands when the flag is false. Agents with the `Bash` tool could technically run any shell command — the gate relies on instructions being followed.

For stricter enforcement:

1. **Tool-level restriction**: remove `Bash` from agents that should not run external commands, or add deny patterns to `.claude/settings.local.json` (e.g., block `git push`, `gh pr create`, `docker push`).
2. **Claude Code's tool-approval dialog**: with a suitable permission mode, Claude Code prompts the user before running any Bash command that matches a risky pattern.

Soft gating is sufficient for most cases. Layer hard gating for adversarial or compliance-heavy environments.

### When to install

**Install** when the project authorizes automated pushes/PRs/releases/registry uploads and you want Claude to handle the full workflow end-to-end.

**Do not install** when any external write would be costly if wrong, when the project requires human approval for every push or release, or when unsure. Default-off is always safe.
