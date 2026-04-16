# claude-resources

Production-grade Claude Code agents and skills for spec-driven development. Turns a generalist AI coding assistant into a team of specialist agents that collaborate through structured specs and reports.

## What this is

Most AI coding assistants generate code without engineering discipline. This framework changes that by providing:

- **Structured workflows** that enforce spec-first, test-proven, review-gated development
- **Specialist agents** that collaborate like a real engineering team — architect, builder, tester, reviewer
- **Skills** that encode battle-tested patterns, not just documentation
- **Operational learning** that captures project-specific knowledge across sessions
- **Token-efficient output** that reduces cost at scale without sacrificing reasoning or spec quality

The result: AI agents that work the way senior engineers do — clarify before building, spec before coding, test before shipping.

## Prerequisites

- **Claude Code** CLI or IDE extension
- **Git** for plugin installation and project detection
- **Bash 4+** — hooks are pure bash, no other runtime required

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

```
/ideate   build a rate limiter for our API gateway
/define   implement token bucket with per-client limits
/plan
/build
/test
/review
```

Each command spawns a specialist agent. Lead pauses for your approval between phases and between groups.

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
