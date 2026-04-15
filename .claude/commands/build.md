---
description: Implement application code following established patterns
---

## Task

Determine if this is a CLI command task or application code:
- CLI commands, flags, config → spawn the `cli-builder` agent
- All other code → spawn the `builder` agent

Pass this task to the agent: $ARGUMENTS

The agent has `core/error-handling` and `core/style` skills loaded, plus language-specific skills auto-loaded from the session-start context (e.g., `go/error-handling`, `go/style`, `go/context`, `go/concurrency`, `go/database`).

If a spec file exists (`SPEC-*.md`), pass it as context to the agent.
Build and run affected tests before reporting done.
