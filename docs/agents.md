# Agents

Reference for the 9 specialist agents in the framework.

Every command routes to exactly one agent. Agents are language-agnostic — they load language-specific skills dynamically from the session-start context. Each agent has a single bounded role, a fixed tool set, a pre-declared skill list, and returns results using the schema in [agent-reporting.md](agent-reporting.md).

## Summary

| Agent | Role | Tools | Memory | Spawned by |
|---|---|---|---|---|
| [critic](#critic) | Task analyst (adversarial) | Read, Grep, Glob, Bash | none | `/ideate`, `/define`, `/orchestrate` |
| [scout](#scout) | Discovery agent (grounds spec in existing code) | Read, Grep, Glob, Bash, Write | project | `/define`, `/orchestrate` |
| [lead](#lead) | Project lead, spec generator, orchestrator, per-group sign-off | Read, Grep, Glob, Bash, Write, Agent | project | `/define`, `/orchestrate` |
| [architect](#architect) | Structure and interface designer | Read, Glob, Grep, Bash, Write, Edit | project | `/plan` |
| [builder](#builder) | Application code implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` |
| [cli-builder](#cli-builder) | CLI tool implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` (CLI path) |
| [tester](#tester) | Test author | Read, Edit, Write, Bash, Grep, Glob | project | `/test` |
| [reviewer](#reviewer) | Code reviewer (read-only) | Read, Grep, Glob, Bash | project | `/review` |
| [shipper](#shipper) | Deployment and observability | Read, Edit, Write, Bash, Grep, Glob | project | `/ship` |

All agents load `core/token-efficiency` by default. Agents that write code also respect the external-writes gate — they check `ops_enabled` in session context before running push, PR, release, or registry commands. See [ops-skills.md](ops-skills.md).

## critic

**Role:** Adversarial task analyst — surfaces gaps, XY problems, scope hazards. Does not write code. Discovery of existing code is scout's job.

**Tools:** Read, Grep, Glob, Bash

**Core skills loaded:** `core/style`, `core/token-efficiency`

**Memory:** none (stateless analyst)

**When to use:**
- First pass on any non-trivial task, in parallel with scout
- Before every spec generation
- When requirements feel incomplete or contradictory
- Proactively, before `/define`, to challenge assumptions

**When NOT to use:**
- Obvious one-line fixes
- Tasks already specified with clear acceptance criteria
- Prior-art surveys (that is scout's role)

**Output:** Structured task definition with problem, scope, approach, out-of-scope, acceptance criteria, and risks. Uses the 5 Whys framework. Within `/define`, critic writes to `docs/specs/<slug>/critique.md`.

## scout

**Role:** Discovery agent that grounds the spec in the existing codebase. Runs in parallel with critic during `/define` and `/orchestrate`. Read-oriented; writes exactly one file per task: `docs/specs/<slug>/discovery.md`.

**Tools:** Read, Grep, Glob, Bash, Write

**Core skills loaded:** `core/discovery`, `core/skill-discovery`, `core/documentation`, `core/style`, `core/token-efficiency`

**Memory:** project

**When to use:**
- In parallel with critic during `/define` — every non-trivial task
- When a task touches code that already exists
- When session learnings flag gotchas in the task's area

**When NOT to use:**
- Greenfield projects with no existing code
- Trivial one-line fixes where the file is already named
- As a replacement for critic — scout does not challenge the request

**Output:** `docs/specs/<slug>/discovery.md` with four sections: Existing Surface (files/functions cited with paths), Patterns to Follow, Inherited Gotchas, Handoff to lead. Every claim cites a file path — unsourced claims do not ship.

## lead

**Role:** Produces spec directories, decomposes tasks into groups, delegates to specialist agents, and pauses after each group for explicit user sign-off. Does not write code.

**Tools:** Read, Grep, Glob, Bash, Write, `Agent` (for spawning subagents)

**Core skills loaded:** `core/spec-generation`, `core/style`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Any task that needs a spec directory
- Multi-step tasks spanning multiple concerns
- Orchestration across multiple specialist agents
- Resumption of an in-progress spec via `/orchestrate --resume <slug>`

**When NOT to use:**
- Single-concern tasks (let the specialist handle it directly)
- Tasks that do not need decomposition

**Output:** `docs/specs/<slug>/` directory with four artifacts (`spec.md`, `discovery.md`, `critique.md`, `group-log.md`), then per-group delegation with mandatory `needs-input` sign-off pauses. See [workflow.md](workflow.md) for group execution and resumption details.

## architect

**Role:** Designs project structure, package boundaries, interface contracts, API surfaces. Runs before implementation.

**Tools:** Read, Glob, Grep, Bash, Write, Edit

**Core skills loaded:** `core/project-structure`, `core/api-design`, `core/security`, `core/documentation`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Starting a new project or major refactor
- Designing a new feature that crosses package boundaries
- Defining interfaces or API surfaces
- Threat-modeling a new feature (design-time security)
- Writing ADRs or architecture docs

**When NOT to use:**
- Implementation details within an existing structure
- Single-file changes

**Output:** Architecture proposal covering package layout, interface contracts, dependency graph, decisions, and risks. User approval required before any files are generated.

## builder

**Role:** Implements application code — handlers, services, repositories, workers.

**Tools:** Read, Edit, Write, Bash, Grep, Glob

**Core skills loaded:** `core/error-handling`, `core/style`, `core/debugging`, `core/git-workflow`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Writing or modifying application code following an approved spec
- Debugging a failing test or production issue
- Following existing architectural patterns

**When NOT to use:**
- Restructuring packages (that is architect's job)
- Writing tests (use tester)
- Adding observability instrumentation (use shipper)

**Output:** Implementation report following the Read → Match → Implement → Verify cycle. Uses `docs/agent-reporting.md` schema: Status, Files touched, Evidence (build and test output), Follow-ups, Blockers.

## cli-builder

**Role:** Implements command-line tools — commands, subcommands, flags, configuration, output formatting.

**Tools:** Read, Edit, Write, Bash, Grep, Glob

**Core skills loaded:** `core/error-handling`, `core/style`, `core/debugging`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Adding a new CLI command or subcommand
- Wiring flags, config files, or environment variables
- Writing output formatters (table, JSON, YAML)
- Implementing signal handling for graceful shutdown

**When NOT to use:**
- Non-CLI application code (use builder)
- Designing a new tool from scratch (use architect first)

**Output:** Command implementation report. Same schema as builder. Evidence includes `--help` output for new or changed commands and exit-code verification.

## tester

**Role:** Writes and runs tests. Applies the prove-it pattern for bug fixes.

**Tools:** Read, Edit, Write, Bash, Grep, Glob

**Core skills loaded:** `core/testing`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Writing unit, integration, or end-to-end tests
- Adding a regression test for a bug fix
- Improving test coverage to meet the pyramid ratio
- Running the test suite with race detection

**When NOT to use:**
- Modifying application code to make tests pass (flag the issue instead)
- Writing tests for trivial getters and setters

**Output:** Test report.

- Status `complete` when all tests pass.
- Status `needs-input` when ANY test fails — failures listed verbatim in Blockers. Tester does NOT auto-retry or auto-fix; the user decides the next move (investigate, fix, revert, stop).
- Status `blocked` when application code is broken in a way that prevents tests from running.

Evidence includes test command output with pass/fail counts.

## reviewer

**Role:** Performs read-only code review across five axes. Never modifies code. Invoked both as an embedded mini-review after each execution group AND as a standalone reviewer via `/review`.

**Tools:** Read, Grep, Glob, Bash

**Core skills loaded:** `core/code-review`, `core/style`, `core/simplification`, `core/security`, `core/performance`, `core/token-efficiency`

**Memory:** project

**Review modes:**
- **Mini-review (per group).** Lead spawns reviewer at the end of every execution group, scoped to that group's changed files only. Findings gate the group's sign-off.
- **Full review (ad hoc).** Invoked by `/review` for standalone review of a diff or package, outside the group flow.

Both modes use the same five-axis framework. Scope differs: mini-review reads only the files listed in the group's task reports; full review walks the full diff.

**When to use:**
- Reviewing any PR before merge
- Auditing AI-generated code
- Reviewing a bug fix and its regression test
- Reviewing large refactors

**When NOT to use:**
- Making the changes yourself (reviewer is read-only)
- Rubber-stamping code without walking the five axes

**Output:** Review report wrapped in the agent-reporting envelope. Evidence is the review itself with severity labels (Critical, Important, Suggestion, Nit, FYI). Files touched is `_None (read-only task)._`.

**Severity drives status:**
- Critical or Important finding → Status `needs-input`. Blockers section lists each finding. Lead cannot advance past the group without explicit user acceptance.
- Suggestion / Nit / FYI only, or no findings → Status `complete`. Lead advances.
- Change too large to review (>1000 lines) → Status `needs-input` with splitting recommendation in Blockers.

## shipper

**Role:** Makes applications production-ready — containerization, logging, metrics, health checks.

**Tools:** Read, Edit, Write, Bash, Grep, Glob

**Core skills loaded:** `core/docker`, `core/observability`, `core/git-workflow`, `core/documentation`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Adding a Dockerfile or optimizing an existing one
- Adding structured logging, metrics, or tracing
- Writing `/healthz` and `/readyz` endpoints
- Preparing a release or deployment

**When NOT to use:**
- Modifying business logic
- Setting up CI/CD pipelines (out of scope)
- Configuring orchestration manifests (Kubernetes, etc.)

**Output:** Deployment report wrapped in the agent-reporting envelope. Evidence is the deployment summary — image details, endpoints added, metrics added, verification checklist. Does not run `docker push`, `kubectl apply`, or any external write unless `ops_enabled=true` in session context.
