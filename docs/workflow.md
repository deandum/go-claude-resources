# Spec-Driven Workflow

Deep-dive into the framework's spec-driven development workflow.

## Overview

The framework follows a spec-driven workflow where every non-trivial task goes through defined phases. The principle: code without a spec is guessing. Specs surface misunderstandings before code, when fixing them is cheap.

Every phase has a dedicated agent, a defined input, and a defined output. No phase proceeds without its predecessor completing.

Every phase that spawns a specialist agent ends with a structured report following the schema in [agent-reporting.md](agent-reporting.md): `Status`, `Files touched`, `Evidence`, `Follow-ups`, and (when blocked) `Blockers`. When `/orchestrate` runs multi-wave work, the `lead` agent parses each report before starting the next wave.

## The Workflow

1. `/ideate` (optional) — Refine a vague idea into a clear task statement
2. `/define` — Critic challenges requirements, lead generates `SPEC-[task].md`
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
| **Who runs** | Lead agent (spawns critic agent first) |
| **Input** | A task description or output from `/ideate` |
| **Output** | `SPEC-[task-slug].md` file in the project root |
| **Key decisions** | What is in scope? What is explicitly out? What are the assumptions? What are the acceptance criteria? |

The define phase is the most critical. The lead agent:

1. Spawns the critic agent to challenge requirements and surface gaps
2. Generates a structured spec file using the spec template
3. Presents the spec for user approval

No implementation begins without explicit user approval of the spec.

### Plan (`/plan`)

| | |
|---|---|
| **Who runs** | Architect agent |
| **Input** | The approved `SPEC-[task-slug].md` |
| **Output** | Project structure design: directory layout, package boundaries, dependency flow |
| **Key decisions** | Package organization, interface contracts, dependency direction, what goes where |

The architect reads the spec and designs the structure. This includes file locations, package boundaries, and the dependency graph between components.

### Build (`/build`)

| | |
|---|---|
| **Who runs** | Builder agent (or cli-builder for CLI tools) |
| **Input** | The approved spec and the architect's structure plan |
| **Output** | Implementation code following the spec's subtask waves |
| **Key decisions** | Implementation details within the boundaries set by the spec |

The builder implements code following the spec's wave structure. Each subtask targets specific files with clear acceptance criteria. The builder stays within the spec's boundaries.

### Test (`/test`)

| | |
|---|---|
| **Who runs** | Tester agent |
| **Input** | The implementation code and the spec's success criteria |
| **Output** | Test suite with passing tests that verify success criteria |
| **Key decisions** | Test strategy, what to test at each level (unit, integration, e2e) |

The tester writes and runs tests that prove the spec's success criteria are met. Tests should be runnable with the exact commands from the spec's Commands section.

### Review (`/review`)

| | |
|---|---|
| **Who runs** | Reviewer agent |
| **Input** | The implementation code and test suite |
| **Output** | 5-axis review covering correctness, security, performance, style, and maintainability |
| **Key decisions** | Whether the code meets quality standards, what needs fixing before shipping |

The reviewer performs a structured code review across five axes. Issues are categorized by severity and each comes with a specific fix suggestion.

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
| **Output** | Coordinated execution across agents following wave structure |
| **Key decisions** | Task decomposition, agent assignment, wave ordering, completion verification |

For complex tasks, `/orchestrate` coordinates the full workflow. The lead agent decomposes work, assigns specialist agents, and manages wave execution. See [commands.md](commands.md#orchestrate) for the full command reference.

## The SPEC File

The spec file is the central artifact. Every spec uses this exact structure:

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

### Wave 1: [description] (parallel)
- [ ] **[agent]** -- [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Wave 2: [description] (depends on Wave 1)
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

## Wave Execution

Waves are groups of subtasks that can run in parallel within the wave:

- **Wave 1** tasks have no dependencies on other subtasks and execute in parallel
- **Wave 2** starts only after ALL Wave 1 tasks complete successfully
- **Wave N+1** starts only after all Wave N tasks complete
- The lead agent coordinates wave execution when using `/orchestrate`
- Each wave task is assigned to the appropriate specialist agent (builder, tester, etc.)
- Each task has a "Done when" criterion that must be verified before the wave is considered complete

### Example wave structure

```
Wave 1 (parallel):
  - builder: Create repository interface in internal/repo/
  - builder: Create domain types in internal/domain/

Wave 2 (depends on Wave 1):
  - builder: Implement HTTP handlers using repository interface
  - tester: Write unit tests for repository and domain types

Wave 3 (depends on Wave 2):
  - tester: Write integration tests for HTTP handlers
  - reviewer: Review all implementation code
```

## Handling Scope Changes

Scope changes during execution follow a strict protocol:

1. **STOP** current implementation work immediately
2. **Update the SPEC** to reflect the new scope
3. **Get explicit user approval** on the revised spec
4. **Resume** execution from the appropriate wave

Never silently expand scope. If a subtask reveals that additional work is needed beyond what the spec covers, that is a scope change and must go through the protocol above.

The critic agent can be re-invoked at any point to challenge scope changes and ensure they are justified.
