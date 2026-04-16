# Documentation

Five docs. Two sections: one for using the framework, one for extending it. Every topic has a single owner — nothing is repeated across files.

## Use the framework

Read in order.

1. **[getting-started.md](getting-started.md)** — install the framework and run through your first `/ideate → /define → /plan → /build → /test → /review` workflow.
2. **[workflow.md](workflow.md)** — the spec-driven workflow deep dive: 7 phases, spec-directory anatomy, group execution, resumption, scope changes.
3. **[reference.md](reference.md)** — every command, agent, and skill the framework ships. The one-stop lookup table.

## Extend the framework

For contributors adding skills, agents, commands, languages, or tuning runtime behavior.

1. **[extending.md](extending.md)** — skill anatomy reference + procedures for adding a core skill, language tier, slash command, or agent (includes the agent reporting schema).
2. **[operations.md](operations.md)** — how the framework runs: lifecycle hooks, the operational learning system, and the opt-in ops plugin for external-write actions.
