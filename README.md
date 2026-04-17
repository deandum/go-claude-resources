# claude-resources

Production-grade Claude Code agents and skills for spec-driven development. Turns a generalist AI coding assistant into a team of specialist agents that collaborate through structured specs and reports.

## What this is

Most AI coding assistants generate code without engineering discipline. This framework changes that by providing:

- **Structured workflows** that enforce spec-first, test-proven, review-gated development
- **Specialist agents** that collaborate like a real engineering team — architect, builder, tester, reviewer
- **Skills** that encode battle-tested patterns, not just documentation
- **Project constitutions** — enforce non-negotiable invariants across every spec and every review
- **Clarification round-trips** — user answers blocker questions before the spec is synthesized, not after
- **Explicit contracts** — optional `contracts.md` for API/data specs pins endpoints, schemas, and error codes
- **Parallelization markers** — `[P]` on every subtask makes parallel-safety auditable
- **Operational learning** that captures project-specific knowledge across sessions
- **Token-efficient output** that reduces cost at scale without sacrificing reasoning or spec quality

The result: AI agents that work the way senior engineers do — clarify before building, spec before coding, test before shipping.

## Prerequisites

- **Claude Code** CLI or IDE extension
- **Git** for plugin installation and project detection
- **Bash 4+** — hooks are pure bash, no other runtime required

**Language support.** Go-specific skills ship by default (15 under `skills/go/`). Other languages are supported via the same extension mechanism; session-start auto-detects `pyproject.toml`, `Cargo.toml`, `package.json`, and `angular.json` and emits the language context, but the `skills/<lang>/` directories for Python, Rust, Node, etc. are not yet populated. See [docs/extending.md](docs/extending.md#adding-a-language) for the steps to add a language tier.

## Quick start

**1. Install:**

```bash
claude plugin add https://github.com/deandum/claude-resources
```

(Alternatives — clone, submodule — are in [docs/getting-started.md](docs/getting-started.md).)

**2. Configure your project:**

```bash
cp claude-resources/EXAMPLE_CLAUDE.md your-project/CLAUDE.md
```

Edit `CLAUDE.md` with your tech stack, build commands, and project boundaries.

**3. Run a workflow:**

For complex tasks, use the single-entry-point flow:

```
/orchestrate  build a rate limiter for our API gateway with per-client 100 req/min limit
```

Main Claude — running the `core/orchestration` skill — walks the full workflow (Phases 1–4, Gates 1–3) and pauses for your approval at every phase boundary and between execution groups. The audit trail lives in `docs/specs/<slug>/group-log.md`.

For ad-hoc steps (no spec, no gates):

```
/ideate  a vague idea you want to sharpen           # optional — produces a clear task
/define  a clear task                                # runs Phase 1 + Phase 2, stops after Gate 2
/build   an already-defined task                     # resumes a spec's Phase 3, or spawns builder directly
/test    a package or function to test               # standalone tester spawn
/review  a diff or branch                            # standalone reviewer spawn
/ship    add containerization + observability        # in-orchestration or ad-hoc shipper
```

Main Claude IS the lead — there is no separate `lead` subagent. Specialist agents (critic, scout, architect, builder, cli-builder, tester, reviewer, shipper) execute bounded work; main Claude gates every phase boundary via `AskUserQuestion`.

## Philosophy

- **Specs prevent rework.** Clarifying requirements before writing code catches misunderstandings early — when they're cheap to fix.
- **Specialist agents produce better results.** An architect thinking about structure and a builder thinking about implementation produce better work than a generalist doing both.
- **Common Rationalizations matter.** The most dangerous shortcuts are the ones that sound reasonable. Explicitly cataloging them prevents clever circumvention.
- **Learning compounds.** Capturing project-specific knowledge across sessions means agents get better at your project over time, not just better at coding.
- **Token efficiency matters at scale.** Verbose output burns tokens without adding value. Compress human-facing prose; never compress specs or agent-to-agent artifacts.

## Documentation

- [Getting started](docs/getting-started.md) — install + first workflow walkthrough
- [Workflow](docs/workflow.md) — spec-driven workflow deep dive
- [Reference](docs/reference.md) — every command, agent, and skill
- [Extending](docs/extending.md) — add your own skills, agents, commands, or languages
- [Operations](docs/operations.md) — hooks, learning system, and the opt-in ops plugin

## License

MIT
