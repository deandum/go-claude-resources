# Spec-Driven Workflow

Deep-dive into the framework's spec-driven development workflow.

## Overview

The framework follows a spec-driven workflow where every non-trivial task goes through defined phases. The principle: code without a spec is guessing. Specs surface misunderstandings before code, when fixing them is cheap.

Every phase has a dedicated agent, a defined input, and a defined output. No phase proceeds without its predecessor completing.

Every phase that spawns a specialist agent ends with a structured report following the schema in [agent-reporting.md](agent-reporting.md): `Status`, `Files touched`, `Evidence`, `Follow-ups`, and (when blocked) `Blockers`. When `/orchestrate` runs multi-group work, the `lead` agent parses each report before starting the next group.

## The Workflow

1. `/ideate` (optional) — Refine a vague idea into a clear task statement
2. `/define` — Critic challenges requirements AND scout grounds them in existing code (parallel); lead synthesizes `docs/specs/<slug>/spec.md`
3. `/plan` — Architect designs package layout, interfaces, dependency graph
4. `/build` — Builder implements code following the spec and existing patterns
5. `/test` — Tester writes tests, applies prove-it pattern for bugs
6. `/review` — Reviewer does five-axis review (correctness, readability, architecture, security, performance)
7. `/ship` — Shipper adds Docker, logging, metrics, health checks

## Phase Details

### Ideate (`/ideate`)

| | |
|---|---|
| **Who runs** | Critic agent |
| **Input** | A vague idea or problem statement from the user |
| **Output** | A concrete task statement with problem, direction, and Not Doing list |
| **Key decisions** | Is the idea worth pursuing? What variations exist? What are the assumptions? |

The ideation phase takes an unrefined idea through three sub-phases:

1. **Understand and Expand** -- Restate as "How Might We", generate 5-8 variations
2. **Evaluate and Converge** -- Stress-test value, feasibility, and differentiation; surface assumptions
3. **Sharpen and Ship** -- Produce a task statement ready for `/define`

Use `/ideate` when you have a direction but not a clear task. Skip it when the task is already well-defined.

### Define (`/define`)

| | |
|---|---|
| **Who runs** | Lead agent (spawns critic and scout in parallel) |
| **Input** | A task description or output from `/ideate` |
| **Output** | Spec directory `docs/specs/<slug>/` with four artifacts: `spec.md`, `discovery.md`, `critique.md`, `group-log.md` |
| **Key decisions** | What is in scope? What is explicitly out? What already exists? What are the assumptions? What are the acceptance criteria? |

The define phase is the most critical. Two sign-off gates fall in this phase — the pre-spec findings review, then the spec itself. Flow:

1. Lead creates `docs/specs/<slug>/` by copying templates from `skills/core/spec-generation/references/`
2. Lead spawns critic AND scout in parallel — critic challenges the request (→ `critique.md`), scout grounds it in existing code (→ `discovery.md`)
3. **Pre-spec findings review (first gate).** Lead presents the raw findings as a `needs-input` report — one-line bullets, not a full spec. User approves, corrects specific bullets, or stops. This gate costs the user seconds, not minutes, and catches phantom assumptions before they get baked into the spec.
4. On approval, lead synthesizes `spec.md` from the findings
5. **Spec approval (Group 0).** Lead presents `spec.md` for user sign-off before any execution begins.

No implementation begins without explicit user approval of the spec.

### Plan (`/plan`)

| | |
|---|---|
| **Who runs** | Architect agent |
| **Input** | The approved `docs/specs/<slug>/spec.md` |
| **Output** | Project structure design: directory layout, package boundaries, dependency flow |
| **Key decisions** | Package organization, interface contracts, dependency direction, what goes where |

The architect reads the spec and designs the structure. This includes file locations, package boundaries, and the dependency graph between components.

### Build (`/build`)

| | |
|---|---|
| **Who runs** | Builder agent (or cli-builder for CLI tools) |
| **Input** | The approved spec and the architect's structure plan |
| **Output** | Implementation code following the spec's subtask groups |
| **Key decisions** | Implementation details within the boundaries set by the spec |

The builder implements code following the spec's group structure. Each subtask targets specific files with clear acceptance criteria. The builder stays within the spec's boundaries.

### Test (`/test`)

| | |
|---|---|
| **Who runs** | Tester agent |
| **Input** | The implementation code and the spec's success criteria |
| **Output** | Test suite with passing tests that verify success criteria |
| **Key decisions** | Test strategy, what to test at each level (unit, integration, e2e) |

The tester writes and runs tests that prove the spec's success criteria are met. Tests should be runnable with the exact commands from the spec's Commands section.

**Test failures surface to the user.** If any test fails, tester returns `needs-input` with the failures listed in Blockers. Tester does NOT auto-retry or auto-fix. The user decides next move: investigate, fix, revert, or stop. Silent retry loops hide signal from the user and are forbidden.

### Review (`/review`)

| | |
|---|---|
| **Who runs** | Reviewer agent |
| **Input** | The implementation code and test suite |
| **Output** | 5-axis review covering correctness, security, performance, style, and maintainability |
| **Key decisions** | Whether the code meets quality standards, what needs fixing before shipping |

The reviewer performs a structured code review across five axes. Issues are categorized by severity and each comes with a specific fix suggestion.

**Review happens twice.** Once as an embedded mini-review at the end of every execution group (scoped to that group's files only), and once standalone via `/review` for ad-hoc full-diff review. Inside `/orchestrate`, the mini-review form is used so review findings arrive incrementally with each group's sign-off, not as one big block at the end.

**Severity drives status.** Critical or Important findings force reviewer's Status to `needs-input` — that blocks the group from advancing until the user explicitly accepts the findings. The reviewer's opinion does not override severity: if a finding is labeled Important, it gates advancement.

### Ship (`/ship`)

| | |
|---|---|
| **Who runs** | Shipper agent |
| **Input** | Reviewed and approved code |
| **Output** | Containerization (Dockerfile), observability setup (logging, metrics, health checks) |
| **Key decisions** | Base image selection, what to observe, alerting thresholds |

The shipper prepares code for production: Docker multi-stage builds, structured logging, metrics instrumentation, health check endpoints, and graceful shutdown.

### Orchestrate (`/orchestrate`)

| | |
|---|---|
| **Who runs** | Lead agent |
| **Input** | A complex task requiring multiple specialist agents |
| **Output** | Coordinated execution across agents following group structure |
| **Key decisions** | Task decomposition, agent assignment, group ordering, completion verification |

For complex tasks, `/orchestrate` coordinates the full workflow. The lead agent decomposes work, assigns specialist agents, and manages group execution. See [commands.md](commands.md#orchestrate) for the full command reference.

## Spec Directory Layout

Specs live under `docs/specs/<slug>/` as a directory containing four artifacts. Templates live at `skills/core/spec-generation/references/` and are copied into place by the lead agent when `/define` runs.

| File | Owner | Purpose |
|------|-------|---------|
| `spec.md` | lead | The contract. Full template body + YAML frontmatter tracking execution state. |
| `discovery.md` | scout | Existing Surface, Patterns to Follow, Inherited Gotchas, Handoff to lead. |
| `critique.md` | critic | Gaps, XY Problems, Scope Hazards, Handoff to lead. |
| `group-log.md` | lead | Append-only. Group 0 records spec approval; Group N records group completion + user decision. |

### Frontmatter on `spec.md`

```yaml
---
task: <slug>
status: draft|approved|in-progress|complete|blocked
current_group: 0|1|...|done
total_groups: <int>
created: <ISO-8601 date>
updated: <ISO-8601 date>
---
```

The frontmatter is authoritative for execution state. `current_group` must stay consistent with the last `## Group N` heading in `group-log.md`.

## The SPEC File Body

The body of `spec.md` uses this exact structure (unchanged from previous versions — only the location changed from project root to `docs/specs/<slug>/`):

```markdown
# Spec: [Task Title]

## Objective
[What we're building and why. 2-3 sentences max.]

## Assumptions
- [Assumption 1 -- surface these upfront]
- [Assumption 2 -- unstated assumptions are where bugs live]

## Scope

### In Scope
- [Concrete deliverable 1]
- [Concrete deliverable 2]

### Out of Scope
- [Explicitly excluded item 1]

## Technical Approach

### Files to Modify/Create
| File | Action | Purpose |
|------|--------|---------|
| `path/to/file` | Modify | [what changes and why] |
| `path/to/new` | Create | [what this adds] |

### Architecture Decisions
- [Decision: why this approach over alternatives]

## Subtasks

### Group 1: [description] (parallel)
- [ ] **[agent]** -- [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Group 2: [description] (depends on Group 1)
- [ ] **[agent]** -- [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

## Commands
```bash
# Build
[exact build command with all flags]
# Test
[exact test command with all flags]
# Lint
[exact lint command with all flags]
```

## Boundaries

### Always do
- [action allowed without asking]

### Ask first
- [high-impact change requiring approval]

### Never do
- [hard stop -- never cross this line]

## Success Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No new linting errors
```

### Spec template rules

- **Objective**: 2-3 sentences. State what AND why. No jargon.
- **Assumptions**: If you are assuming something, say it. Better to be wrong early than wrong in production.
- **Scope**: "Out of Scope" prevents scope creep. Be explicit about what you are not doing.
- **Files table**: Exact paths. Agents execute literally -- ambiguity becomes errors.
- **Subtasks**: One agent per task. Each task completable in isolation. Each has an acceptance criterion.
- **Commands**: Exact commands with flags. Not "run tests" -- give the full command with every flag.
- **Boundaries**: Three tiers prevent ambiguity. "Ask first" is for judgment calls.
- **Success Criteria**: Every criterion must be verifiable with a command or observable evidence. "Works correctly" is NOT a criterion. "GET /api/v1/orders returns 200 with order list" IS.

## Group Execution

Groups bundle subtasks that can run in parallel within a group:

- **Group 0** is the spec approval itself (recorded in `group-log.md`)
- **Group 1** tasks have no dependencies on other subtasks and execute in parallel
- **Group 2** starts only after ALL Group 1 tasks complete successfully AND the user has approved Group 1
- **Group N+1** starts only after all Group N tasks complete AND the user approves Group N
- The lead agent coordinates group execution when using `/orchestrate`
- Each group task is assigned to the appropriate specialist agent (builder, tester, etc.)
- Each task has a "Done when" criterion that must be verified before the group is considered complete

### Per-group sign-off

After every group's parallel tasks complete, lead walks three steps before pausing for user sign-off:

1. **Collect task reports.** If any task returned `needs-input` (test failures, ambiguous inputs), surface that to the user BEFORE continuing. No auto-retries.
2. **Run a mini-review.** Lead spawns `reviewer` scoped to the files this group touched. The review is incremental — only this group's changes, not the whole diff. Critical or Important findings force `needs-input`.
3. **Emit the group report.** One-line-per-task summary table first (signal), reviewer findings second (quality), full per-task detail last (reference). The user reads 5-10 lines and drills in only if needed.

The sign-off prompt asks: `"Approve group N and proceed to group N+1? (reply 'approve', 'changes: <what>', or 'stop')"`.

On `approve`: lead records the decision in `group-log.md`, updates frontmatter `current_group`, spawns group N+1.
On `changes: <what>`: lead updates the spec, re-runs affected tasks, re-presents the group.
On `stop`: lead sets `status: blocked` in frontmatter, records the stop in `group-log.md`, halts.

This reuses the existing `needs-input` status from the agent-reporting schema — no new vocabulary introduced for group-review pauses.

### Keeping cognitive load low

Four design choices keep the user's review windows small:

- **Pre-spec gate.** User sees raw critic + scout findings as one-line bullets before any spec exists. Phantom assumptions get corrected while the fix costs seconds, not rewriting a spec.
- **Task summary first.** Group reports lead with a one-line-per-task table. The user gets signal immediately; full agent reports are available but not the default view.
- **Mini-review per group.** The quality lens lands incrementally with each group, not as one big block at the end. By the time final verification runs, everything has already been reviewed.
- **Surface failures, don't hide them.** Test failures and Critical/Important review findings force `needs-input`. No silent retry loops; no implicit advancement past quality gates.

At no point is the user asked to review a full implementation without incremental feedback along the way.

### Resumption

A session that ends mid-execution (user walks away, process dies, context fills up) leaves the spec directory in a recoverable state. On the next session start, `session-start.sh` scans `docs/specs/*/spec.md` and emits an `active_specs` JSON field listing any spec whose `status != complete`. Format: `<slug>:<current_group>/<total_groups>`, comma-joined.

The lead agent reads `active_specs` on its first response and surfaces in-progress specs: *"Detected in-progress spec `<slug>` at group N/M. Resume (`/orchestrate --resume <slug>`), ignore, or mark blocked?"*. The user makes an explicit choice.

Resume with `/orchestrate --resume <slug>`. Lead re-reads the spec directory, validates `current_group` against `group-log.md`, and restarts at the next pending group. Completed groups are never re-run.

### Example group structure

```
Group 1 (parallel):
  - builder: Create repository interface in internal/repo/
  - builder: Create domain types in internal/domain/

Group 2 (depends on Group 1):
  - builder: Implement HTTP handlers using repository interface
  - tester: Write unit tests for repository and domain types

Group 3 (depends on Group 2):
  - tester: Write integration tests for HTTP handlers
  - reviewer: Review all implementation code
```

## Handling Scope Changes

Scope changes during execution follow a strict protocol:

1. **STOP** current implementation work immediately
2. **Update `spec.md`** to reflect the new scope
3. **Get explicit user approval** on the revised spec (re-record in `group-log.md` if the change is significant)
4. **Resume** execution from the appropriate group

Never silently expand scope. If a subtask reveals that additional work is needed beyond what the spec covers, that is a scope change and must go through the protocol above.

The critic agent can be re-invoked at any point to challenge scope changes and ensure they are justified. The scout agent can be re-invoked when the scope change touches an area of the codebase not explored during the initial discovery.
