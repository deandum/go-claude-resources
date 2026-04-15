# claude-resources

Production-grade Claude Code agents and skills for spec-driven development. Encodes senior engineering judgment into repeatable agent workflows.

**Two-tier architecture**: core skills (language-agnostic workflows) + language skills (implementation patterns). Currently supports Go, with Angular and other languages planned.

## What This Is

Most AI coding assistants generate code without engineering discipline. This framework changes that by providing:

- **Structured workflows** that enforce spec-first, test-proven, review-gated development
- **Specialist agents** that collaborate like a real engineering team (architect, builder, tester, reviewer)
- **Skills** that encode battle-tested patterns, not just documentation
- **Operational learning** that captures project-specific knowledge across sessions
- **Token-efficient output** that reduces cost at scale without sacrificing reasoning or spec quality

The result: AI agents that work the way senior engineers do — clarify before building, spec before coding, test before shipping — while keeping token costs under control.

## Prerequisites

- **Claude Code** CLI or IDE extension
- **Git** for plugin installation and project detection
- **Bash 4+** — hooks are pure bash; no python or other runtime required

## Quick Start

### 1. Install

```bash
# As a Claude Code plugin (recommended)
claude plugin add https://github.com/deandumitru/claude-resources

# Or clone locally
git clone https://github.com/deandumitru/claude-resources.git
```

### 2. Configure your project

Copy the example config into your project root:

```bash
cp claude-resources/EXAMPLE_CLAUDE.md your-project/CLAUDE.md
```

Edit `CLAUDE.md` with your tech stack, build commands, and project boundaries.

### 3. Start working

```
/ideate    → Refine a vague idea into a clear task
/define    → Generate a structured SPEC from requirements
/build     → Implement code following the SPEC
/test      → Write and run tests
/review    → Five-axis code review
```

See [Getting Started](docs/getting-started.md) for a full walkthrough.

## Slash Commands

| Command | Purpose | Agent |
|---------|---------|-------|
| `/ideate` | Refine a vague idea into a task ready for /define | critic |
| `/define` | Analyze requirements, generate structured SPEC | critic + lead |
| `/plan` | Design architecture and project structure | architect |
| `/build` | Implement code following established patterns | builder / cli-builder |
| `/test` | Write and run tests for the codebase | tester |
| `/review` | Five-axis code review (read-only) | reviewer |
| `/ship` | Containerize and add observability | shipper |
| `/orchestrate` | Decompose complex task into waves of agent work | lead |
| `/learn` | Record a project-specific learning for future sessions | — |
| `/compact` | Set output compression level for token efficiency | — |

## Agents

| Agent | Role | Scope |
|-------|------|-------|
| **critic** | Challenges vague requirements, surfaces assumptions | Runs first. Does NOT write code. |
| **lead** | Produces SPEC files, decomposes tasks, delegates to team | Coordinates. Never writes code directly. |
| **architect** | Designs package layout, interfaces, API surfaces | Before implementation. |
| **builder** | Implements handlers, services, repositories, workers | Follows existing patterns. |
| **cli-builder** | Builds CLI commands, flags, config handling | Cobra, Viper, stdlib. |
| **tester** | Writes tests, creates test doubles, prove-it pattern | After implementation. |
| **reviewer** | Five-axis code review with severity labels | Read-only. |
| **shipper** | Docker, logging, metrics, health checks | Production readiness. |

All agents auto-detect project language and load appropriate skills.

## Skills

### Core (19 language-agnostic workflow skills)

Organized by development phase:

| Phase | Skills | Purpose |
|-------|--------|---------|
| **Define** | `idea-refine` `spec-generation` `skill-discovery` | Clarify requirements, generate specs |
| **Plan** | `project-structure` `api-design` `documentation` | Design architecture, interfaces, record decisions |
| **Build** | `error-handling` `concurrency` `style` `debugging` | Implementation discipline |
| **Test** | `testing` | Test strategy and verification |
| **Review** | `code-review` `simplification` `security` `performance` | Quality disciplines (design-time and review-time) |
| **Ship** | `docker` `observability` `git-workflow` | Release and production readiness |
| **Cross-cutting** | `token-efficiency` | Output compression and cost control |

Every core skill follows a standard anatomy: **When to Use**, **When NOT to Use**, **Core Process**, **Common Rationalizations** (shortcuts that sound reasonable but aren't), **Red Flags**, and **Verification**. See [Skill Anatomy](docs/skill-anatomy.md).

### Go (15 implementation skills)

| Category | Skills |
|----------|--------|
| **Error & validation** | `error-handling` `interface-design` |
| **Concurrency** | `concurrency` `context` |
| **Data** | `database` `modules` |
| **Quality** | `testing` `testing-with-framework` `code-review` `style` |
| **APIs** | `cli` `api-design` |
| **Deployment** | `docker` `observability` `project-init` |

### Ops (4 opt-in external-write skills — NOT enabled by default)

The `ops-skills` plugin is separate and **not installed by default**. Install it only in projects where Claude is authorized to write to external services (push to git, create PRs, publish releases, push container images).

| Skill | Purpose |
|-------|---------|
| `git-remote` | `git push`, force-push policy, upstream tracking, tag push |
| `pull-requests` | `gh pr create`, PR templates, review response, merge strategy |
| `release` | Semver decision, tag creation, changelog, GitHub Releases |
| `registry` | `docker push`, tag strategy, image signing, registry authentication |

**How detection works.** The `session-start.sh` hook checks whether `skills/ops/` is present and populated. If yes, `ops_enabled: true` is emitted in the session JSON; agents consult this flag before running any external-write command. If no, agents refuse to run the command and report it as a follow-up instead.

**Installing the ops plugin:**

```bash
# Via marketplace (when claude-resources is published)
claude plugin add ops-skills

# Or, if working from a local clone, the skills/ops/ directory is already present
# and session-start.sh will detect it automatically.
```

**Not installing it.** The default state (no ops plugin) means every external-write action surfaces as a follow-up in agent reports — the user sees what Claude *would* do, but Claude does not execute it. This is the recommended default for any project where unintended side effects would be costly.

## Spec-Driven Workflow

Every non-trivial task follows a structured flow:

1. `/ideate` (optional) — Refine a vague idea into a clear task statement
2. `/define` — Critic challenges requirements, lead generates `SPEC-[task].md`
3. `/plan` — Architect designs package layout, interfaces, dependency graph
4. `/build` — Builder implements code following the spec and existing patterns
5. `/test` — Tester writes tests, applies prove-it pattern for bugs
6. `/review` — Reviewer does five-axis review (correctness, readability, architecture, security, performance)
7. `/ship` — Shipper adds Docker, logging, metrics, health checks

The SPEC file is the contract. Agents consume it directly. If scope changes, update the spec first. See [Workflow](docs/workflow.md) for the full deep-dive.

## Operational Learning

The framework captures project-specific knowledge across sessions, preventing agents from rediscovering the same conventions, gotchas, and patterns.

**Record a learning:**
```
/learn the auth service requires X-Request-ID header for all endpoints
```

**How it works:**
1. During a session, agents record non-obvious discoveries via `hooks/learn.sh`
2. At session end, learnings are collected into `~/.claude-resources/learnings/{project}.jsonl`
3. At next session start, the last 10 learnings are injected as context

**Example learnings:**
```json
{"learning":"MySQL driver silently truncates strings >255 chars in name column","category":"gotcha","timestamp":"2026-04-07T14:30:00Z"}
{"learning":"All repositories use internal/db wrapper, not raw sqlx","category":"pattern","timestamp":"2026-04-07T15:00:00Z"}
```

See [Operational Learning](docs/operational-learning.md) for full documentation.

## Project Structure

```
skills/
├── core/              # 19 language-agnostic workflow skills
│   ├── idea-refine/
│   ├── spec-generation/
│   ├── skill-discovery/
│   ├── token-efficiency/
│   └── ...
└── go/                # 15 Go implementation skills
    ├── error-handling/
    ├── testing/
    ├── concurrency/
    └── ...
agents/                # 8 specialist agents
hooks/                 # Session lifecycle + learning system
├── session-start.sh   # Language detection, skill loading, learning injection
├── session-end.sh     # Learning collection and persistence
└── learn.sh           # Record a learning during a session
.claude/commands/      # 10 slash commands (entry points)
.claude-plugin/        # Plugin manifest + marketplace registry
docs/                  # Deep-dive documentation
references/            # Cross-cutting reference material
```

## Contributing

Key quality criteria: every addition must be **specific**, **verifiable**, **battle-tested**, and **minimal**. See the Adding a Language / Adding a Skill sections in [CLAUDE.md](CLAUDE.md).

## Documentation

| Document | Purpose |
|----------|---------|
| [Getting Started](docs/getting-started.md) | Installation, first workflow, customization |
| [Workflow](docs/workflow.md) | Spec-driven workflow deep-dive, SPEC template |
| [Skill Anatomy](docs/skill-anatomy.md) | Skill structure reference, writing guidelines |
| [Operational Learning](docs/operational-learning.md) | Learning system lifecycle, JSONL format |
| [EXAMPLE_CLAUDE.md](EXAMPLE_CLAUDE.md) | Template for project-specific configuration |

## Philosophy

This framework exists because code generation without engineering discipline creates technical debt faster than it creates value. The key insights:

- **Specs prevent rework.** Clarifying requirements before writing code catches misunderstandings early — when they're cheap to fix.
- **Specialist agents produce better results.** An architect thinking about structure and a builder thinking about implementation produce better work than a generalist doing both.
- **Common Rationalizations matter.** The most dangerous shortcuts are the ones that sound reasonable. Explicitly cataloging them prevents clever circumvention.
- **Learning compounds.** Capturing project-specific knowledge across sessions means agents get better at your project over time, not just better at coding.
- **Token efficiency matters at scale.** Verbose output burns tokens without adding value. Compress human-facing prose, never agent-to-agent artifacts. Specs stay full-fidelity — they're prompts for other agents, not output for humans.

## License

MIT
