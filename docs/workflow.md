# Spec-Driven Workflow

Deep-dive into the framework's spec-driven development workflow.

## Overview

Every non-trivial task goes through defined phases. The principle: code without a spec is guessing. Specs surface misunderstandings before code, when fixing them is cheap.

Every phase has a dedicated agent, a defined input, and a defined output. No phase proceeds without its predecessor completing. Every phase that spawns a specialist agent ends with a structured report (schema in [extending.md](extending.md#agent-reporting)). When `/orchestrate` runs multi-group work, `lead` parses each report before starting the next group.

## The workflow

1. `/ideate` (optional) — Refine a vague idea into a clear task statement
2. `/define` — Critic challenges requirements AND scout grounds them in existing code (parallel); lead synthesizes `docs/specs/<slug>/spec.md`
3. `/plan` — Architect designs package layout, interfaces, dependency graph
4. `/build` — Builder implements code following the spec and existing patterns
5. `/test` — Tester writes tests, applies prove-it pattern for bugs
6. `/review` — Reviewer does five-axis review (correctness, readability, architecture, security, performance)
7. `/ship` — Shipper adds Docker, logging, metrics, health checks

## Phase details

### Ideate (`/ideate`)

| | |
|---|---|
| **Who runs** | Critic agent |
| **Input** | A vague idea or problem statement from the user |
| **Output** | A concrete task statement with problem, direction, and Not Doing list |
| **Key decisions** | Is the idea worth pursuing? What variations exist? What are the assumptions? |

Three sub-phases: Understand and Expand, Evaluate and Converge, Sharpen and Ship. Use `/ideate` when you have a direction but not a clear task. Skip it when the task is already well-defined.

### Define (`/define`)

| | |
|---|---|
| **Who runs** | Lead agent (spawns critic and scout in parallel) |
| **Input** | A task description or output from `/ideate` |
| **Output** | Spec directory `docs/specs/<slug>/` with four artifacts: `spec.md`, `discovery.md`, `critique.md`, `group-log.md` |
| **Key decisions** | What is in scope? What is explicitly out? What already exists? What are the assumptions? What are the acceptance criteria? |

Two sign-off gates: the pre-spec findings review, then the spec itself. Critic writes `critique.md` (gaps, XY problems); scout writes `discovery.md` (prior art, patterns, gotchas). Lead presents the raw findings for user review before synthesizing `spec.md`. No implementation begins without explicit spec approval.

For the full template, frontmatter schema, and sign-off protocol, see [`core/spec-generation/SKILL.md`](../skills/core/spec-generation/SKILL.md).

### Plan (`/plan`)

| | |
|---|---|
| **Who runs** | Architect agent |
| **Input** | The approved `docs/specs/<slug>/spec.md` |
| **Output** | Project structure design: directory layout, package boundaries, dependency flow |
| **Key decisions** | Package organization, interface contracts, dependency direction, what goes where |

### Build (`/build`)

| | |
|---|---|
| **Who runs** | Builder (or cli-builder for CLI tools) |
| **Input** | The approved spec and the architect's structure plan |
| **Output** | Implementation code following the spec's subtask groups |
| **Key decisions** | Implementation details within the boundaries set by the spec |

### Test (`/test`)

| | |
|---|---|
| **Who runs** | Tester agent |
| **Input** | The implementation code and the spec's success criteria |
| **Output** | Test suite with passing tests that verify success criteria |
| **Key decisions** | Test strategy, what to test at each level (unit, integration, e2e) |

**Test failures surface to the user.** If any test fails, tester returns `needs-input` with failures listed in Blockers. Tester does NOT auto-retry or auto-fix.

### Review (`/review`)

| | |
|---|---|
| **Who runs** | Reviewer agent |
| **Input** | The implementation code and test suite |
| **Output** | Five-axis review covering correctness, security, performance, style, maintainability |
| **Key decisions** | Whether the code meets quality standards, what needs fixing before shipping |

**Review happens twice.** Once as an embedded mini-review at the end of every execution group (scoped to that group's files), and once standalone via `/review` for ad-hoc review. Critical or Important findings force `needs-input` — they block group advancement until the user explicitly accepts them.

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
| **Who runs** | Lead agent |
| **Input** | A complex task requiring multiple specialist agents |
| **Output** | Coordinated execution across agents following group structure |
| **Key decisions** | Task decomposition, agent assignment, group ordering, completion verification |

For complex tasks, `/orchestrate` coordinates the full workflow. See [`agents/lead.md`](../agents/lead.md) for the full orchestration contract (Step 0 through Step 6).

## Spec directory

Specs live under `docs/specs/<slug>/` as a directory of four artifacts. Templates live at `skills/core/spec-generation/references/` and are copied into place by lead when `/define` runs.

| File | Owner | Purpose |
|------|-------|---------|
| `spec.md` | lead | The contract. Template body + YAML frontmatter tracking execution state. |
| `discovery.md` | scout | Existing Surface, Patterns to Follow, Inherited Gotchas, Handoff to lead. |
| `critique.md` | critic | Gaps, XY Problems, Scope Hazards, Handoff to lead. |
| `group-log.md` | lead | Append-only. Group 0 records spec approval; Group N records group completion + user decision. |

For the spec template body, frontmatter schema (`task`, `status`, `current_group`, `total_groups`, `created`, `updated`), and authoring rules, see [`core/spec-generation/SKILL.md`](../skills/core/spec-generation/SKILL.md).

## Group execution

Groups bundle subtasks that can run in parallel within a group:

- **Group 0** is spec approval itself (recorded in `group-log.md`).
- **Group N** tasks run in parallel. The next group starts only after all Group N tasks complete AND the user approves Group N.
- Lead coordinates group execution when using `/orchestrate`.
- Each task has a "Done when" criterion verified before the group completes.

After every group, lead runs a scoped mini-review, then pauses for explicit sign-off (`approve` / `changes: <what>` / `stop`). Critical or Important review findings force `needs-input` — no silent advancement past quality gates.

For the per-group sign-off shape, mini-review scoping, and resumption protocol, see [`agents/lead.md`](../agents/lead.md) Step 5.

### Resumption

A session that ends mid-execution leaves the spec directory in a recoverable state. On next session start, `session-start.sh` scans `docs/specs/*/spec.md` and emits `active_specs` listing any spec where `status != complete`. Resume with `/orchestrate --resume <slug>` — lead re-reads the spec, validates `current_group` against `group-log.md`, and restarts at the next pending group. Completed groups are never re-run.

## Handling scope changes

Scope changes during execution follow a strict protocol:

1. **STOP** current implementation work immediately
2. **Update `spec.md`** to reflect the new scope
3. **Get explicit user approval** on the revised spec (re-record in `group-log.md` if the change is significant)
4. **Resume** execution from the appropriate group

Never silently expand scope. If a subtask reveals that additional work is needed beyond what the spec covers, that is a scope change and must go through the protocol above.

Critic can be re-invoked at any point to challenge scope changes. Scout can be re-invoked when the change touches an area not explored during initial discovery.

## End-to-end example

A concrete flow, start to finish:

1. **A session starts.** Claude Code fires `SessionStart`. `session-start.sh` runs, detects the project language, lists available skills, loads recent operational learnings, scans `docs/specs/*/spec.md` for in-progress tasks (emits `active_specs`), and emits a JSON block into session context.

2. **The user types a slash command.** Say `/define build a rate limiter`. The command file in `.claude/commands/define.md` instructs Claude to spawn the `lead` agent.

3. **Lead reads the session context.** Sees `detected_languages: "go"` and knows to load Go-specific skills from its `## Language-Specific Skills` section. Checks `active_specs` — if any are in progress, it surfaces them before starting fresh work.

4. **Lead spawns critic AND scout in parallel.** Critic challenges the request (writes `critique.md`). Scout greps the codebase, reads similar features, cites file paths for every finding (writes `discovery.md`). They do not coordinate mid-task; lead synthesizes.

5. **Lead creates the spec directory.** Copies every file from `skills/core/spec-generation/references/` into `docs/specs/rate-limiter/`, then populates `spec.md` with frontmatter plus the template body — folding scout's findings into Assumptions and Technical Approach, and critic's findings into Out of Scope and Boundaries.

6. **The user approves the spec (Group 0).** Lead records the decision in `group-log.md` and updates frontmatter `status: approved`. Nothing proceeds without explicit approval.

7. **The user runs `/build`.** Spawns builder with `docs/specs/rate-limiter/spec.md` as context. Builder reads the spec literally — files to modify, acceptance criteria, commands to run.

8. **Builder implements the group.** Loads `core/error-handling`, `core/debugging`, `core/git-workflow`, `core/style`, plus Go-specific equivalents. Writes code, runs tests, returns a structured report.

9. **Lead parses the report and pauses for sign-off.** Writes a new Group N section to `group-log.md` and emits a `needs-input` report asking the user to `approve`, `changes: <what>`, or `stop`. Execution does not advance without explicit sign-off.

10. **A new learning surfaces.** During the work, builder discovered the project uses a non-obvious repository pattern. It calls `learn.sh` to record the learning to a `/tmp` buffer.

11. **The session ends.** `session-end.sh` collects the buffer files, appends them to `~/.claude-resources/learnings/<project-slug>.jsonl`, and prunes to the last 50 entries. The spec directory remains on disk with its current frontmatter state.

12. **Resumption.** When the user starts a new session, `session-start.sh` detects that `rate-limiter` is still in progress and emits `active_specs: "rate-limiter:2/4"`. Lead surfaces the in-progress spec on its first response. The user runs `/orchestrate --resume rate-limiter` and execution picks up at the next pending group.

The framework is this flow, repeated. Every command is an entry point. Every agent is a specialist. Every skill is a unit of knowledge the agent loads to do its work.
