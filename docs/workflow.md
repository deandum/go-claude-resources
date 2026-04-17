# Spec-Driven Workflow

Deep-dive into the framework's spec-driven development workflow.

## Overview

Every non-trivial task goes through defined phases. The principle: code without a spec is guessing. Specs surface misunderstandings before code, when fixing them is cheap.

Every phase has a dedicated agent, a defined input, and a defined output. No phase proceeds without its predecessor completing. Every phase that spawns a specialist agent ends with a structured report (schema in [extending.md](extending.md#agent-reporting)). Main Claude — running the `core/orchestration` skill — parses each report and drives the state machine. Main Claude IS the lead; there is no `lead` subagent.

## The workflow

1. `/ideate` (optional) — Refine a vague idea into a clear task statement
2. `/define` — Main Claude spawns critic + scout in parallel, gates findings, synthesizes `docs/specs/<slug>/spec.md`, gates spec approval
3. `/plan` — Architect designs package layout, interfaces, dependency graph (ad-hoc) or populates `contracts.md` (in-orchestration)
4. `/build` — Builder/cli-builder/shipper implements code following the spec. In-orchestration: resume Phase 3 per group, gated. Ad-hoc: direct spawn.
5. `/test` — Tester writes tests, applies prove-it pattern for bugs (standalone; never auto-fixes)
6. `/review` — Reviewer does five-axis review (correctness, readability, architecture, security, performance)
7. `/ship` — Shipper adds Docker, logging, metrics, health checks
8. `/orchestrate` — Full workflow: Phase 1 → 2 → 3 → 4 with gates at every boundary

## Phase details

### Ideate (`/ideate`)

| | |
|---|---|
| **Who runs** | Critic agent (spawned with `core/idea-refine`) |
| **Input** | A vague idea or problem statement from the user |
| **Output** | A concrete task statement with problem, direction, and Not Doing list |
| **Key decisions** | Is the idea worth pursuing? What variations exist? What are the assumptions? |

Three sub-phases: Understand and Expand, Evaluate and Converge, Sharpen and Ship. Use `/ideate` when you have a direction but not a clear task. Skip it when the task is already well-defined.

### Define (`/define`)

| | |
|---|---|
| **Who runs** | Main Claude, loading `core/orchestration` (spawns critic and scout in parallel) |
| **Input** | A task description or output from `/ideate` |
| **Output** | Spec directory `docs/specs/<slug>/` with four required artifacts (`spec.md`, `discovery.md`, `critique.md`, `group-log.md`) plus an optional fifth (`contracts.md`) for API/data-heavy specs |
| **Key decisions** | What is in scope? What is explicitly out? What already exists? What are the assumptions? What are the acceptance criteria? |

Three HITL gates before any execution: Gate 1 findings review, optional Gate 1 clarification round-trip when critic surfaces `Blocker: yes` questions, and Gate 2 spec approval. Critic writes `critique.md` (gaps, XY problems, clarifying questions); scout writes `discovery.md` (prior art, patterns, gotchas). Main Claude presents the raw findings via `AskUserQuestion` before synthesizing `spec.md`. No implementation begins without explicit spec approval (Gate 2).

**Contracts artifact.** The orchestration workflow scans the task description for API/data markers (`REST`, `endpoint`, `schema`, `webhook`, `event`, `payload`, `migration`, ...). If matched, it copies `contracts.md` alongside the four required templates. After spec approval, `architect` populates it with endpoints, payload schemas, error codes, and data invariants. Reviewer treats contract mismatches as Critical findings during mini-review.

For the template, frontmatter schema, and spec-directory contract, see [`core/spec-generation/SKILL.md`](../skills/core/spec-generation/SKILL.md). For the workflow that populates them, see [`core/orchestration/SKILL.md`](../skills/core/orchestration/SKILL.md).

### Plan (`/plan`)

| | |
|---|---|
| **Who runs** | Architect agent, spawned directly by main Claude |
| **Input** | In-orchestration: approved `spec.md` + `discovery.md` + unpopulated `contracts.md`. Ad-hoc: a design request from the user. |
| **Output** | Populated `contracts.md` (in-orchestration) or a design proposal in the architect's report Evidence (ad-hoc). |
| **Key decisions** | Package organization, interface contracts, dependency direction, what goes where |

### Build (`/build`)

| | |
|---|---|
| **Who runs** | Builder, cli-builder, or shipper, spawned by main Claude |
| **Input** | A self-contained prompt — task description, `Files:` line, `Done when:` criterion, relevant decisions quoted verbatim, verify command |
| **Output** | Implementation code following the spec's subtask for the current group |
| **Key decisions** | Implementation details within the boundaries set by the spec |

In-orchestration mode resumes Phase 3 and spawns one group's tasks at a time with a per-group gate (`approve` / `changes: <what>` / `stop`) between every group. Ad-hoc mode skips gates.

### Test (`/test`)

| | |
|---|---|
| **Who runs** | Tester agent (standalone — NOT an orchestration entry point) |
| **Input** | A self-contained prompt with `Files:` scoped to `*_test.*` paths and a verify command |
| **Output** | Test suite with passing tests that verify the acceptance criterion |
| **Key decisions** | Test strategy, what to test at each level (unit, integration, e2e) |

**Test failures surface to the user.** If any test fails, tester returns `needs-input` with failures listed in Blockers. Tester does NOT auto-retry or auto-fix. Tester also refuses to write to non-test files — if the prompt's `Files:` line names an application file, tester returns `blocked`.

### Review (`/review`)

| | |
|---|---|
| **Who runs** | Reviewer agent |
| **Input** | In mini-review mode: an explicit `Files:` list from main Claude. In full-review mode (`/review`): a diff scope. |
| **Output** | Five-axis review covering correctness, readability, architecture, security, performance |
| **Key decisions** | Whether the code meets quality standards, what needs fixing before shipping |

**Review happens twice.** Once as an embedded mini-review at the end of every Phase 3 execution group (scoped to that group's files), and once standalone via `/review` for ad-hoc review. Critical or Important findings force `needs-input` — they block group advancement until the user explicitly accepts them.

### Ship (`/ship`)

| | |
|---|---|
| **Who runs** | Shipper agent |
| **Input** | Reviewed and approved code |
| **Output** | Containerization (Dockerfile), observability setup (logging, metrics, health checks) |
| **Key decisions** | Base image selection, what to observe, alerting thresholds |

### Orchestrate (`/orchestrate`)

| | |
|---|---|
| **Who runs** | Main Claude, loading `core/orchestration` |
| **Input** | A complex task requiring multiple specialist agents |
| **Output** | Coordinated execution across agents following group structure, with gates at every phase boundary |
| **Key decisions** | Task decomposition, agent assignment, group ordering, completion verification |

For complex tasks, `/orchestrate` runs the full workflow (Phase 1 through Phase 4, Gate 1 through Gate 3). See [`skills/core/orchestration/SKILL.md`](../skills/core/orchestration/SKILL.md) for the complete contract.

## Spec directory

Specs live under `docs/specs/<slug>/` as a directory of four required artifacts plus one optional artifact. Templates live at `skills/core/spec-generation/references/` and are copied into place by main Claude when `/define` runs.

| File | Owner | Purpose |
|------|-------|---------|
| `spec.md` | main Claude | The contract. Template body + YAML frontmatter tracking execution state. Every subtask carries a `[P]` parallelization marker. |
| `discovery.md` | scout | Existing Surface, Patterns to Follow, Inherited Gotchas, Handoff to main Claude. |
| `critique.md` | critic | Gaps, XY Problems, Scope Hazards, Clarifying Questions, Resolutions. |
| `group-log.md` | main Claude | Append-only audit trail. Group 0 records spec approval; each gate decision and each subagent spawn is recorded with an ISO-8601 timestamp. |
| `contracts.md` | architect | Optional. Copied for API/data-heavy specs; populated after spec approval. Endpoints, payload schemas, error codes, events, data invariants. |

For the spec template body, frontmatter schema (`task`, `status`, `current_group`, `total_groups`, `created`, `updated`), and authoring rules, see [`core/spec-generation/SKILL.md`](../skills/core/spec-generation/SKILL.md).

**Constitution.** Projects with `docs/constitution.md` at the repo root emit a `project_constitution` field in session context. Reviewer grades every diff against the listed invariants; critic uses them as the Scope Hazards reference frame during `/define`. See [`skills/core/constitution/SKILL.md`](../skills/core/constitution/SKILL.md).

## Group execution

Groups bundle subtasks that can run in parallel within a group:

- **Group 0** is spec approval itself (recorded in `group-log.md`).
- **Group N** tasks run in parallel. Every task carries a `[P]` marker declaring it parallel-safe with siblings — reviewer audits the marker against the task's `Files:` list, and overlapping writes with `[P]` markers is a Critical finding.
- The next group starts only after all Group N tasks complete AND the user approves Group N via `AskUserQuestion`.
- Main Claude coordinates group execution when running `/orchestrate` or `/build` in in-orchestration mode.
- Each task has a "Done when" criterion verified before the group completes.

After every group, main Claude spawns `reviewer` in mini-review mode (scoped to the group's changed files), then pauses for explicit sign-off (`approve` / `changes: <what>` / `stop`). Critical or Important review findings force `needs-input` — no silent advancement past quality gates.

For the per-group sign-off shape, mini-review scoping, and resumption protocol, see [`skills/core/orchestration/SKILL.md`](../skills/core/orchestration/SKILL.md) Phase 3 (Steps 8–13).

### Resumption

A session that ends mid-execution leaves the spec directory in a recoverable state. On next session start, `session-start.sh` scans `docs/specs/*/spec.md` and emits `active_specs` listing any spec where `status != complete`. Main Claude surfaces this on its first response via `AskUserQuestion`. Resume with `/orchestrate --resume <slug>` — main Claude re-reads the spec, validates `current_group` against `group-log.md`, and restarts at the next pending group. Completed groups are never re-run.

## Handling scope changes

Scope changes during execution follow a strict protocol:

1. **STOP** current implementation work immediately
2. **Update `spec.md`** to reflect the new scope, appending a `_revision_N_` note with timestamp and reason. Revert frontmatter `status: draft`.
3. **Re-run Gate 2** — present the revised spec and collect `approve` / `changes: <what>` / `stop` via `AskUserQuestion`
4. **Resume** execution from the appropriate group once approved

Never silently expand scope. If a subtask reveals that additional work is needed beyond what the spec covers, that is a scope change and must go through the protocol above. The audit trail in `group-log.md` records the revision.

Critic can be re-invoked at any point to challenge scope changes. Scout can be re-invoked when the change touches an area not explored during initial discovery.

## End-to-end example

A concrete flow, start to finish:

1. **A session starts.** Claude Code fires `SessionStart`. `session-start.sh` runs, detects the project language, lists available skills, loads recent operational learnings, scans `docs/specs/*/spec.md` for in-progress tasks (emits `active_specs`), and emits a JSON block into session context.

2. **The user types a slash command.** Say `/define build a rate limiter`. The command file `.claude/commands/define.md` instructs main Claude to load `core/orchestration` and run Phase 1 + Phase 2.

3. **Main Claude reads the session context.** Sees `detected_languages: "go"` — language-specific skills will be loaded by delegated agents. Checks `active_specs` — if any are in progress, surfaces them via `AskUserQuestion` before starting fresh work.

4. **Main Claude spawns critic AND scout in parallel.** One assistant message with two `Agent` tool calls. Critic challenges the request (writes `critique.md`). Scout greps the codebase, reads similar features, cites file paths for every finding (writes `discovery.md`). They do not coordinate mid-task; main Claude synthesizes.

5. **Gate 1 — findings review.** Main Claude presents one-line bullets per finding via `AskUserQuestion`. User replies `approve` / `correct: <bullet>` / `stop`. No spec synthesis until findings are approved.

6. **Main Claude synthesizes `spec.md`.** Populates every template section. Frontmatter starts at `status: draft`, `current_group: 0`.

7. **Gate 2 — spec approval.** Main Claude presents `spec.md` via `AskUserQuestion`. On `approve`: sets `status: approved`, records "Group 0: Spec approval" in `group-log.md` with the user's verbatim reply and an ISO timestamp.

8. **The user runs `/build`.** Main Claude resumes Phase 3. Updates frontmatter `status: in-progress`, `current_group: 1`. Spawns builder with a self-contained prompt — task description, `Files:` line, `Done when:` criterion, relevant decisions quoted verbatim, verify command. Builder does NOT read `spec.md` wholesale.

9. **Builder implements the group.** Loads `core/error-handling`, `core/debugging`, `core/git-workflow`, `core/style`, plus Go-specific equivalents. Writes code, runs the verify command, returns a structured report.

10. **Main Claude spawns `reviewer` scoped to the group.** Reviewer walks the explicit file list (no `git diff` in mini-review mode). Returns findings labeled by severity.

11. **Per-group gate.** Main Claude appends a "Group 1" section to `group-log.md` with the task summary table, mini-review findings, and timestamp, then asks `AskUserQuestion` with options `approve` / `changes: <what>` / `stop`. Critical/Important findings surfaced in the question body.

12. **A new learning surfaces.** During the work, builder discovered the project uses a non-obvious repository pattern. It calls `learn.sh` to record the learning to a `/tmp` buffer.

13. **The session ends.** `session-end.sh` collects the buffer files, appends them to `~/.claude-resources/learnings/<project-slug>.jsonl`, and prunes to the last 50 entries. The spec directory remains on disk with its current frontmatter state.

14. **Resumption.** When the user starts a new session, `session-start.sh` detects that `rate-limiter` is still in progress and emits `active_specs: "rate-limiter:2/4"`. Main Claude surfaces the in-progress spec on its first response via `AskUserQuestion`. The user runs `/orchestrate --resume rate-limiter` and execution picks up at the next pending group.

The framework is this flow, repeated. Every command is an entry point. Every agent is a specialist. Every skill is a unit of knowledge the agent loads to do its work. Main Claude is the orchestrator — not a subagent.
