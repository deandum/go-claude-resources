# Agents

Reference for the 8 specialist agents in the framework.

Every command routes to exactly one agent. Agents are language-agnostic — they load language-specific skills dynamically from the session-start context. Each agent has a single bounded role, a fixed tool set, a pre-declared skill list, and returns results using the schema in [agent-reporting.md](agent-reporting.md).

## Summary

| Agent | Role | Tools | Memory | Spawned by |
|---|---|---|---|---|
| [critic](#critic) | Task analyst | Read, Grep, Glob, Bash | none | `/ideate`, `/define` |
| [lead](#lead) | Project lead, spec generator, orchestrator | Read, Grep, Glob, Bash, Write, Agent | project | `/define`, `/orchestrate` |
| [architect](#architect) | Structure and interface designer | Read, Glob, Grep, Bash, Write, Edit | project | `/plan` |
| [builder](#builder) | Application code implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` |
| [cli-builder](#cli-builder) | CLI tool implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` (CLI path) |
| [tester](#tester) | Test author | Read, Edit, Write, Bash, Grep, Glob | project | `/test` |
| [reviewer](#reviewer) | Code reviewer (read-only) | Read, Grep, Glob, Bash | project | `/review` |
| [shipper](#shipper) | Deployment and observability | Read, Edit, Write, Bash, Grep, Glob | project | `/ship` |

All agents load `core/token-efficiency` by default. Agents that write code also respect the external-writes gate — they check `ops_enabled` in session context before running push, PR, release, or registry commands. See [ops-skills.md](ops-skills.md).

## critic

**Role:** Analyzes task requests, surfaces gaps, challenges vague requirements. Does not write code.

**Tools:** Read, Grep, Glob, Bash

**Core skills loaded:** `core/style`, `core/token-efficiency`

**Memory:** none (stateless analyst)

**When to use:**
- First pass on any non-trivial task
- Before every spec generation
- When requirements feel incomplete or contradictory
- Proactively, before `/define`, to challenge assumptions

**When NOT to use:**
- Obvious one-line fixes
- Tasks already specified with clear acceptance criteria

**Output:** Structured task definition with problem, scope, approach, out-of-scope, acceptance criteria, and risks. Uses the 5 Whys framework.

## lead

**Role:** Produces SPEC files, decomposes tasks into waves, delegates to specialist agents. Does not write code.

**Tools:** Read, Grep, Glob, Bash, Write, `Agent` (for spawning subagents)

**Core skills loaded:** `core/spec-generation`, `core/style`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Any task that needs a SPEC file
- Multi-step tasks spanning multiple concerns
- Orchestration across multiple specialist agents

**When NOT to use:**
- Single-concern tasks (let the specialist handle it directly)
- Tasks that do not need decomposition

**Output:** `SPEC-[task-slug].md` in the project root, then per-wave delegation reports parsed against the spec's acceptance criteria. See [workflow.md](workflow.md) for wave execution details.

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

**Output:** Test report. Status is `complete` only when tests pass. Evidence includes test command output with pass counts.

## reviewer

**Role:** Performs read-only code review across five axes. Never modifies code.

**Tools:** Read, Grep, Glob, Bash

**Core skills loaded:** `core/code-review`, `core/style`, `core/simplification`, `core/security`, `core/performance`, `core/token-efficiency`

**Memory:** project

**When to use:**
- Reviewing any PR before merge
- Auditing AI-generated code
- Reviewing a bug fix and its regression test
- Reviewing large refactors

**When NOT to use:**
- Making the changes yourself (reviewer is read-only)
- Rubber-stamping code without walking the five axes

**Output:** Review report wrapped in the agent-reporting envelope. Evidence is the review itself with severity labels (Critical, Important, Suggestion, Nit, FYI). Files touched is `_None (read-only task)._`. Status is `complete` unless the change is too large to review (in that case: `needs-input` with a splitting recommendation).

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
