# Skills Catalog

A lightweight index of all 38 skills in the framework, grouped by tier and purpose.

This is a catalog, not a reference. Each entry has a one-line purpose and a link to the full `SKILL.md` file. For the anatomy of a skill (sections, frontmatter, style rules), see [skill-anatomy.md](skill-anatomy.md). To learn how skills load into agent context, see [architecture.md](architecture.md).

## Core skills (19)

Language-agnostic workflow skills. Grouped by phase.

### Define phase

| Skill | Purpose |
|---|---|
| [idea-refine](../skills/core/idea-refine/SKILL.md) | Pre-spec ideation — divergent then convergent thinking, produce a "Not Doing" list. Meta-skill invoked by `/ideate`. |
| [spec-generation](../skills/core/spec-generation/SKILL.md) | Structured SPEC template — objective, assumptions, scope, subtasks in waves, commands, boundaries, success criteria |
| [skill-discovery](../skills/core/skill-discovery/SKILL.md) | Decision tree for routing tasks to the right agent. Meta-skill loaded on session start, not by agents directly. |

### Plan phase

| Skill | Purpose |
|---|---|
| [project-structure](../skills/core/project-structure/SKILL.md) | Entity-focused architecture, dependency rules, package boundaries |
| [api-design](../skills/core/api-design/SKILL.md) | HTTP API patterns — parse → validate → execute → respond, request/response separation, versioning |
| [documentation](../skills/core/documentation/SKILL.md) | When to write prose — ADRs, README maintenance, inline-comment policy |

### Build phase

| Skill | Purpose |
|---|---|
| [error-handling](../skills/core/error-handling/SKILL.md) | Sentinel, custom, wrapped errors; propagation rules; boundary mapping |
| [concurrency](../skills/core/concurrency/SKILL.md) | Channels vs mutexes, worker pools, fan-out/fan-in, rate limiting, pipelines |
| [style](../skills/core/style/SKILL.md) | Clarity over cleverness — naming, function design, comment policy |
| [debugging](../skills/core/debugging/SKILL.md) | Reproduce → triage → bisect → root cause → fix with regression test |

### Test phase

| Skill | Purpose |
|---|---|
| [testing](../skills/core/testing/SKILL.md) | Test pyramid, prove-it pattern for bugs, mock hierarchy, setup/teardown |

### Review phase

| Skill | Purpose |
|---|---|
| [code-review](../skills/core/code-review/SKILL.md) | Five-axis review (correctness, readability, architecture, security, performance) with severity labels |
| [simplification](../skills/core/simplification/SKILL.md) | Chesterton's Fence, YAGNI, dead-code removal, three-coupled-duplications rule |
| [security](../skills/core/security/SKILL.md) | Threat modeling, authz/authn design, secrets, input validation at boundaries — design-time discipline |
| [performance](../skills/core/performance/SKILL.md) | Profile before optimize, benchmarking, N+1 detection — design-time discipline |

### Ship phase

| Skill | Purpose |
|---|---|
| [docker](../skills/core/docker/SKILL.md) | Multi-stage builds, base image selection, layer caching, security |
| [observability](../skills/core/observability/SKILL.md) | Structured logging, RED/USE metrics, distributed tracing, health checks, alerting |
| [git-workflow](../skills/core/git-workflow/SKILL.md) | Local git discipline — commit hygiene, branching, rebase, PR body content |

### Cross-cutting

| Skill | Purpose |
|---|---|
| [token-efficiency](../skills/core/token-efficiency/SKILL.md) | Output compression for human-facing responses — never for SPEC files or agent-to-agent reports |

## Go skills (15)

Language-specific implementation patterns. Loaded automatically when `go.mod` is detected.

### Error handling

| Skill | Purpose |
|---|---|
| [go/error-handling](../skills/go/error-handling/SKILL.md) | `fmt.Errorf` with `%w`, sentinel errors, custom types, `errors.Is`/`errors.As`, HTTP error mapping |

### Concurrency and context

| Skill | Purpose |
|---|---|
| [go/concurrency](../skills/go/concurrency/SKILL.md) | `errgroup`, worker pools, fan-out/fan-in, pipelines, rate limiters, `sync.Once`/singleflight |
| [go/context](../skills/go/context/SKILL.md) | Context propagation, cancellation, timeouts, type-safe context values |

### Data

| Skill | Purpose |
|---|---|
| [go/database](../skills/go/database/SKILL.md) | MySQL with `sqlx`, connection pooling, transactions, repository pattern, `*Context` methods |
| [go/modules](../skills/go/modules/SKILL.md) | `go.mod`/`go.sum`, versioning, replace directives, workspaces, `govulncheck`, CI validation |

### Quality

| Skill | Purpose |
|---|---|
| [go/testing](../skills/go/testing/SKILL.md) | Table-driven tests with `tt`/`tc`, function-based mocks, `t.Helper`, Arrange-Act-Assert |
| [go/testing-with-framework](../skills/go/testing-with-framework/SKILL.md) | Ginkgo/Gomega BDD — Describe/Context/It, `DescribeTable`, `Eventually`/`Consistently` |
| [go/code-review](../skills/go/code-review/SKILL.md) | Go-specific review checklist — correctness, style, concurrency, performance, security |
| [go/style](../skills/go/style/SKILL.md) | `gofmt`/`goimports`, initialisms, receiver types, code organization, anti-patterns |

### APIs

| Skill | Purpose |
|---|---|
| [go/api-design](../skills/go/api-design/SKILL.md) | Chi router, handler structure, JSON helpers (`DisallowUnknownFields`), graceful shutdown |
| [go/cli](../skills/go/cli/SKILL.md) | Cobra and Viper, subcommands, flag precedence, `signal.NotifyContext`, exit codes |
| [go/interface-design](../skills/go/interface-design/SKILL.md) | Accept interfaces return concrete, consumer-side definition, interface segregation, compile-time verification |

### Deployment

| Skill | Purpose |
|---|---|
| [go/docker](../skills/go/docker/SKILL.md) | Multi-stage build with `CGO_ENABLED=0`, `-ldflags='-w -s'`, distroless + nonroot |
| [go/observability](../skills/go/observability/SKILL.md) | `slog` setup, Prometheus `MustRegister` + `/metrics`, OpenTelemetry `initTracer`, health checks |
| [go/project-init](../skills/go/project-init/SKILL.md) | Service/CLI/library scaffolding, dependencies, post-scaffold checklist |

## Ops skills (4, opt-in)

External-write discipline. **Not enabled by default.** Requires `ops_enabled=true` in session context — see [ops-skills.md](ops-skills.md).

| Skill | Purpose |
|---|---|
| [ops/git-remote](../skills/ops/git-remote/SKILL.md) | `git push`, force-push policy, upstream tracking, tag push |
| [ops/pull-requests](../skills/ops/pull-requests/SKILL.md) | `gh pr create`, PR templates, review response, merge strategy selection |
| [ops/release](../skills/ops/release/SKILL.md) | Semver decision, tag creation, changelog generation, GitHub Releases |
| [ops/registry](../skills/ops/registry/SKILL.md) | `docker push`, immutable vs mutable tags, image signing, registry authentication |

## Loading behavior

- **Core skills** are loaded by agents based on each agent's `skills:` frontmatter list. Every agent loads `core/token-efficiency`. Role-specific skills vary (e.g., the reviewer loads `core/code-review`, `core/simplification`, `core/security`, `core/performance`).
- **Go skills** are loaded by agents when `go.mod` is detected and the agent's `## Language-Specific Skills` section maps Go to a skill list.
- **Ops skills** are loaded only when the `ops-skills` plugin is installed and `ops_enabled=true` in session context.

For the full agent skill mappings, see [agents.md](agents.md). For the full workflow that coordinates these skills, see [workflow.md](workflow.md).
