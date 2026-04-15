# Slash Commands

Reference for the 10 slash commands shipped with the framework.

Commands are the entry points for the spec-driven workflow. Each command routes to exactly one agent (or runs as a utility with no agent). Command files live in `.claude/commands/` — they are small by design (10–25 lines each) and contain no language-detection logic (that comes from the session-start hook).

## Summary

| Command | Purpose | Agent | Phase |
|---|---|---|---|
| [/ideate](#ideate) | Refine a vague idea into a clear task | `critic` | Define (pre) |
| [/define](#define) | Generate a structured SPEC file | `lead` (spawns `critic`) | Define |
| [/plan](#plan) | Design architecture and structure | `architect` | Plan |
| [/build](#build) | Implement application code | `builder` or `cli-builder` | Build |
| [/test](#test) | Write and run tests | `tester` | Test |
| [/review](#review) | Five-axis code review | `reviewer` | Review |
| [/ship](#ship) | Containerize and add observability | `shipper` | Ship |
| [/orchestrate](#orchestrate) | Decompose and delegate to multiple agents | `lead` | Cross-phase |
| [/learn](#learn) | Record a project-specific learning | utility (none) | Cross-phase |
| [/compact](#compact) | Set output compression level | utility (none) | Cross-phase |

## /ideate

**Purpose:** Refine a vague idea into a concrete task statement ready for `/define`.

**Args:** A free-text idea or problem statement.

**Agent spawned:** `critic`

**Phase:** Pre-Define (optional)

**When to use:**
- You have a direction but not a clear task
- The request is vague ("something about rate limiting")
- Multiple framings are possible and you want to explore before committing

**When NOT to use:**
- The task is already well-defined
- You already have acceptance criteria

**Example:**

```
/ideate build a rate limiter for our API gateway
```

The critic walks three phases: understand and expand, evaluate and converge, sharpen and ship. Output is a task statement with problem, direction, and a "Not Doing" list — ready to feed into `/define`.

## /define

**Purpose:** Analyze task requirements and generate a structured spec file.

**Args:** A task description (may come from `/ideate` output).

**Agent spawned:** `lead` (which spawns `critic` first for requirement clarification)

**Phase:** Define — the most critical phase

**When to use:**
- Any task that needs a SPEC (multi-file, multi-step, or more than ~30 min of work)
- Before any implementation begins

**When NOT to use:**
- Trivial one-line fixes
- Tasks that are already specified with clear acceptance criteria

**Example:**

```
/define implement token bucket rate limiter with per-client limits, 100 req/s default
```

Output: `SPEC-rate-limiter.md` in the project root. User approval is required before any downstream command runs.

## /plan

**Purpose:** Design project architecture, package layout, interfaces, and dependency flow.

**Args:** Optional — reads the approved SPEC file by default.

**Agent spawned:** `architect`

**Phase:** Plan (after `/define`)

**When to use:**
- New project or major restructuring
- Adding a feature that crosses package boundaries
- Defining new interfaces or API surfaces

**When NOT to use:**
- Implementation within an existing structure (use `/build`)
- Single-file changes

**Example:**

```
/plan
```

The architect reads the approved spec and proposes a structure. User approval is required before any files are generated.

## /build

**Purpose:** Implement application code following the spec and existing patterns.

**Args:** Optional — reads the approved SPEC file by default.

**Agent spawned:** `builder` for application code, `cli-builder` for CLI commands and flags.

**Phase:** Build

**When to use:**
- Writing or modifying code after a SPEC is approved
- Debugging a failing test or production issue
- Applying a fix that follows established patterns

**When NOT to use:**
- Before the spec is approved
- Restructuring or designing (use `/plan`)

**Example:**

```
/build
```

The builder reads the spec, executes subtasks in wave order, and reports using the [agent-reporting.md](agent-reporting.md) schema.

## /test

**Purpose:** Write and run tests covering the implementation.

**Args:** Optional — can target specific packages or files.

**Agent spawned:** `tester`

**Phase:** Test (after `/build`)

**When to use:**
- Writing unit, integration, or E2E tests for new code
- Adding a regression test for a bug fix (prove-it pattern)
- Improving coverage

**When NOT to use:**
- Before code exists
- When the application code itself is broken (flag the issue, do not modify it)

**Example:**

```
/test
```

Runs tests with race detection where available. Status is `complete` only when tests pass.

## /review

**Purpose:** Five-axis code review — correctness, readability, architecture, security, performance.

**Args:** Optional — targets the current diff by default.

**Agent spawned:** `reviewer`

**Phase:** Review

**When to use:**
- Before merging any PR
- After completing a feature implementation
- After any bug fix (review both the fix and the regression test)
- Auditing AI-generated code

**When NOT to use:**
- Before the code exists or builds
- As a substitute for testing (use `/test`)

**Example:**

```
/review
```

Reviewer is read-only. Every finding gets a severity label: Critical, Important, Suggestion, Nit, or FYI. Critical and Important findings must include a specific fix recommendation.

## /ship

**Purpose:** Containerize the application and add observability — logging, metrics, health checks.

**Args:** Optional — operates on the whole service by default.

**Agent spawned:** `shipper`

**Phase:** Ship (after review passes)

**When to use:**
- Preparing a service for production deployment
- Adding structured logging or metrics to an existing service
- Writing a Dockerfile or optimizing an existing one

**When NOT to use:**
- To modify business logic
- To set up CI/CD pipelines (out of scope)
- To push images or deploy to clusters (those require `ops-skills` — see [ops-skills.md](ops-skills.md))

**Example:**

```
/ship
```

Audits current state first, then adds: structured logging → health checks → metrics → Dockerfile. Does not run `docker push` unless `ops_enabled=true`.

## /orchestrate

**Purpose:** Decompose a complex task into waves and delegate subtasks to specialist agents.

**Args:** A complex task description.

**Agent spawned:** `lead`

**Phase:** Cross-phase (coordinates other phases)

**When to use:**
- Tasks spanning multiple concerns or multiple agents
- Multi-package or multi-service work
- Any task that needs wave execution

**When NOT to use:**
- Single-concern tasks (call the command for that concern directly)
- Tasks that fit in one agent's role

**Example:**

```
/orchestrate migrate the user service from postgres to cockroachdb
```

The lead agent spawns `critic` to clarify, generates a spec, seeks user approval, then runs waves — spawning builder, tester, reviewer, and others in parallel within waves, serializing across waves.

## /learn

**Purpose:** Record a project-specific learning for future sessions.

**Args:** The learning text, optionally followed by a category.

**Agent spawned:** None — utility command that runs `hooks/learn.sh` directly.

**Phase:** Any

**When to use:**
- You discovered a non-obvious convention, gotcha, pattern, or tool setting
- A future session would waste time rediscovering this

**When NOT to use:**
- For things already documented in CLAUDE.md or README
- For standard language idioms
- For temporary debugging notes

**Example:**

```
/learn the auth service requires X-Request-ID on all endpoints
/learn MySQL driver truncates strings >255 chars silently gotcha
```

Categories: `convention` (default), `gotcha`, `pattern`, `tool`. See [operational-learning.md](operational-learning.md) for the full lifecycle.

## /compact

**Purpose:** Set the output compression level for the current session.

**Args:** Optional — one of `standard`, `compressed`, `minimal`. No arg toggles between standard and compressed.

**Agent spawned:** None — utility command.

**Phase:** Any

**When to use:**
- To reduce token usage in long-running sessions
- When producing many agent reports in succession
- When the user wants terser output

**When NOT to use:**
- To compress SPEC files or agent-to-agent reports (these are never compressed — they are prompts for other agents)

**Example:**

```
/compact compressed
```

Levels:
- **standard** — drop articles, filler, pleasantries, hedging
- **compressed** — standard plus abbreviations, fragments, tables over paragraphs
- **minimal** — bullet-only, paths and status only

See `skills/core/token-efficiency/SKILL.md` for the full content-type decision table.
