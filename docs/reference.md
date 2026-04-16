# Reference

Single reference page for everything the framework ships: 11 commands, 9 agents, and 40 skills. Each entry links to the authoritative file — this page is an index, not a second copy.

## Commands

Commands are the entry points. Each routes to exactly one agent (or runs as a utility). Command files are small by design (10–25 lines) and contain no language-detection logic — detection lives in `session-start.sh`.

| Command | Purpose | Agent | Phase |
|---|---|---|---|
| [/ideate](../.claude/commands/ideate.md) | Refine a vague idea into a clear task | `critic` | Define (pre) |
| [/define](../.claude/commands/define.md) | Generate a spec directory | `lead` (spawns `critic` + `scout` in parallel) | Define |
| [/plan](../.claude/commands/plan.md) | Design architecture and structure | `architect` | Plan |
| [/build](../.claude/commands/build.md) | Implement application code | `builder` or `cli-builder` | Build |
| [/test](../.claude/commands/test.md) | Write and run tests | `tester` | Test |
| [/review](../.claude/commands/review.md) | Five-axis code review | `reviewer` | Review |
| [/ship](../.claude/commands/ship.md) | Containerize and add observability | `shipper` | Ship |
| [/orchestrate](../.claude/commands/orchestrate.md) | Decompose and delegate (supports `--resume <slug>`) | `lead` | Cross-phase |
| [/constitution-propose](../.claude/commands/constitution-propose.md) | Propose candidate invariants for `docs/constitution.md` from codebase evidence | `lead` (spawns `scout` + `critic` in parallel) | Governance |
| [/learn](../.claude/commands/learn.md) | Record a project-specific learning | utility | Cross-phase |
| [/compact](../.claude/commands/compact.md) | Set output compression level | utility | Cross-phase |

Notes:

- `/orchestrate --resume <slug>` picks up an in-progress spec from `docs/specs/<slug>/`. Lead validates `current_group` against `group-log.md` before restarting.
- `/compact` accepts `standard` (default), `compressed`, or `minimal`. See [`core/token-efficiency`](../skills/core/token-efficiency/SKILL.md).
- `/learn` accepts a learning text and optional category (`convention`, `gotcha`, `pattern`, `tool`). See [operations.md](operations.md) for the lifecycle.

## Agents

Every command routes to exactly one agent. Agents are language-agnostic — they load language-specific skills dynamically from session-start context. Each agent ends its work with a structured report (schema in [extending.md](extending.md#agent-reporting)).

| Agent | Role | Tools | Memory | Spawned by |
|---|---|---|---|---|
| [critic](../agents/critic.md) | Task analyst (adversarial) | Read, Grep, Glob, Bash | none | `/ideate`, `/define`, `/orchestrate` |
| [scout](../agents/scout.md) | Discovery — grounds spec in existing code | Read, Grep, Glob, Bash, Write | project | `/define`, `/orchestrate` |
| [lead](../agents/lead.md) | Spec generator + orchestrator + per-group sign-off | Read, Grep, Glob, Bash, Write, Agent | project | `/define`, `/orchestrate` |
| [architect](../agents/architect.md) | Structure and interface designer | Read, Glob, Grep, Bash, Write, Edit | project | `/plan` |
| [builder](../agents/builder.md) | Application code implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` |
| [cli-builder](../agents/cli-builder.md) | CLI tool implementer | Read, Edit, Write, Bash, Grep, Glob | project | `/build` (CLI path) |
| [tester](../agents/tester.md) | Test author | Read, Edit, Write, Bash, Grep, Glob | project | `/test` |
| [reviewer](../agents/reviewer.md) | Code reviewer (read-only) | Read, Grep, Glob, Bash | project | `/review` |
| [shipper](../agents/shipper.md) | Deployment and observability | Read, Edit, Write, Bash, Grep, Glob | project | `/ship` |

Shared conventions:

- All agents load `core/token-efficiency` by default.
- Code-writing agents (`builder`, `cli-builder`, `shipper`, `lead`) consult `ops_enabled` in session context before running external-write commands. See [operations.md](operations.md#ops-plugin-opt-in).
- Language-specific skills load dynamically from the session-start context, not hardcoded in agent files.
- For full role descriptions, skill lists, and process rules, read the agent file directly.

## Skills

40 total: 21 core (language-agnostic), 15 Go (language-specific), 4 ops (opt-in external writes).

### Core skills (21) — language-agnostic

Every core skill follows the same anatomy: When to Use, When NOT, Core Process, Common Rationalizations, Red Flags, Verification. See [extending.md](extending.md#skill-anatomy) for the full template.

**Define phase**

| Skill | Purpose |
|---|---|
| [idea-refine](../skills/core/idea-refine/SKILL.md) | Pre-spec ideation — divergent then convergent thinking, "Not Doing" list. Invoked by `/ideate`. |
| [discovery](../skills/core/discovery/SKILL.md) | Ground a task in the existing codebase. Loaded by scout during `/define`. |
| [spec-generation](../skills/core/spec-generation/SKILL.md) | Structured SPEC template and spec-directory layout — objective, assumptions, scope, subtasks in groups, commands, boundaries, success criteria, frontmatter state tracking. |
| [skill-discovery](../skills/core/skill-discovery/SKILL.md) | Decision tree for routing tasks to the right agent. Meta-skill loaded on session start. |

**Plan phase**

| Skill | Purpose |
|---|---|
| [project-structure](../skills/core/project-structure/SKILL.md) | Entity-focused architecture, dependency rules, package boundaries. |
| [api-design](../skills/core/api-design/SKILL.md) | HTTP API patterns — parse → validate → execute → respond, request/response separation, versioning. |
| [documentation](../skills/core/documentation/SKILL.md) | When to write prose — ADRs, README maintenance, inline-comment policy. |

**Build phase**

| Skill | Purpose |
|---|---|
| [error-handling](../skills/core/error-handling/SKILL.md) | Sentinel, custom, wrapped errors; propagation rules; boundary mapping. |
| [concurrency](../skills/core/concurrency/SKILL.md) | Channels vs mutexes, worker pools, fan-out/fan-in, rate limiting, pipelines. |
| [style](../skills/core/style/SKILL.md) | Clarity over cleverness — naming, function design, comment policy. |
| [debugging](../skills/core/debugging/SKILL.md) | Reproduce → triage → bisect → root cause → fix with regression test. |

**Test phase**

| Skill | Purpose |
|---|---|
| [testing](../skills/core/testing/SKILL.md) | Test pyramid, prove-it pattern for bugs, mock hierarchy, setup/teardown. |

**Review phase**

| Skill | Purpose |
|---|---|
| [code-review](../skills/core/code-review/SKILL.md) | Five-axis review (correctness, readability, architecture, security, performance) with severity labels. |
| [simplification](../skills/core/simplification/SKILL.md) | Chesterton's Fence, YAGNI, dead-code removal, three-coupled-duplications rule. |
| [security](../skills/core/security/SKILL.md) | Threat modeling, authz/authn design, secrets, input validation at boundaries — design-time discipline. |
| [performance](../skills/core/performance/SKILL.md) | Profile before optimize, benchmarking, N+1 detection — design-time discipline. |

**Ship phase**

| Skill | Purpose |
|---|---|
| [docker](../skills/core/docker/SKILL.md) | Multi-stage builds, base image selection, layer caching, security. |
| [observability](../skills/core/observability/SKILL.md) | Structured logging, RED/USE metrics, distributed tracing, health checks, alerting. |
| [git-workflow](../skills/core/git-workflow/SKILL.md) | Local git discipline — commit hygiene, branching, rebase, PR body content. |

**Governance**

| Skill | Purpose |
|---|---|
| [constitution](../skills/core/constitution/SKILL.md) | Author and maintain project invariants (`docs/constitution.md`) that reviewer and critic enforce. Severity-driven: `critical` blocks advancement, `important` flags without blocking. |

**Cross-cutting**

| Skill | Purpose |
|---|---|
| [token-efficiency](../skills/core/token-efficiency/SKILL.md) | Output compression for human-facing responses — never for SPEC files or agent-to-agent reports. |

### Go skills (15) — language-specific

Loaded automatically when `go.mod` is detected at project root.

| Skill | Purpose |
|---|---|
| [go/error-handling](../skills/go/error-handling/SKILL.md) | `fmt.Errorf` with `%w`, sentinel errors, custom types, `errors.Is`/`errors.As`, HTTP error mapping. |
| [go/concurrency](../skills/go/concurrency/SKILL.md) | `errgroup`, worker pools, fan-out/fan-in, pipelines, rate limiters, `sync.Once`/singleflight. |
| [go/context](../skills/go/context/SKILL.md) | Context propagation, cancellation, timeouts, type-safe context values. |
| [go/database](../skills/go/database/SKILL.md) | MySQL with `sqlx`, connection pooling, transactions, repository pattern, `*Context` methods. |
| [go/modules](../skills/go/modules/SKILL.md) | `go.mod`/`go.sum`, versioning, replace directives, workspaces, `govulncheck`, CI validation. |
| [go/testing](../skills/go/testing/SKILL.md) | Table-driven tests with `tt`/`tc`, function-based mocks, `t.Helper`, Arrange-Act-Assert. |
| [go/testing-with-framework](../skills/go/testing-with-framework/SKILL.md) | Ginkgo/Gomega BDD — Describe/Context/It, `DescribeTable`, `Eventually`/`Consistently`. |
| [go/code-review](../skills/go/code-review/SKILL.md) | Go-specific review checklist — correctness, style, concurrency, performance, security. |
| [go/style](../skills/go/style/SKILL.md) | `gofmt`/`goimports`, initialisms, receiver types, code organization, anti-patterns. |
| [go/api-design](../skills/go/api-design/SKILL.md) | Chi router, handler structure, JSON helpers (`DisallowUnknownFields`), graceful shutdown. |
| [go/cli](../skills/go/cli/SKILL.md) | Cobra and Viper, subcommands, flag precedence, `signal.NotifyContext`, exit codes. |
| [go/interface-design](../skills/go/interface-design/SKILL.md) | Accept interfaces return concrete, consumer-side definition, interface segregation, compile-time verification. |
| [go/docker](../skills/go/docker/SKILL.md) | Multi-stage build with `CGO_ENABLED=0`, `-ldflags='-w -s'`, distroless + nonroot. |
| [go/observability](../skills/go/observability/SKILL.md) | `slog` setup, Prometheus `MustRegister` + `/metrics`, OpenTelemetry `initTracer`, health checks. |
| [go/project-init](../skills/go/project-init/SKILL.md) | Service/CLI/library scaffolding, dependencies, post-scaffold checklist. |

### Ops skills (4) — opt-in

Only loaded when the `ops-skills` plugin is installed and `ops_enabled=true` in session context. See [operations.md](operations.md#ops-plugin-opt-in) for installation and gating.

| Skill | Purpose |
|---|---|
| [ops/git-remote](../skills/ops/git-remote/SKILL.md) | `git push`, force-push policy, upstream tracking, tag push. |
| [ops/pull-requests](../skills/ops/pull-requests/SKILL.md) | `gh pr create`, PR templates, review response, merge strategy selection. |
| [ops/release](../skills/ops/release/SKILL.md) | Semver decision, tag creation, changelog generation, GitHub Releases. |
| [ops/registry](../skills/ops/registry/SKILL.md) | `docker push`, immutable vs mutable tags, image signing, registry authentication. |

## Loading behavior

- **Core skills**: loaded by agents based on each agent's `skills:` frontmatter list. Every agent loads `core/token-efficiency`.
- **Language skills**: loaded when the language marker file is detected at the project root (e.g., `go.mod` for Go) and the agent's `## Language-Specific Skills` section maps the language to a skill list.
- **Ops skills**: loaded only when the `ops-skills` plugin is installed (populating `skills/ops/`) and `ops_enabled=true` in session context.

Language detection runs once per session in `hooks/session-start.sh`. Detection happens at the project root, resolved via `git rev-parse --show-toplevel` with a fallback to the working directory.
