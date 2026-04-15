---
description: Implement application code following established patterns
---

## Task

Determine if this is a CLI command task or application code:
- CLI commands, flags, config → spawn the `cli-builder` agent
- All other code → spawn the `builder` agent

Pass this task to the agent: $ARGUMENTS

The agent has `core/error-handling` and `core/style` skills loaded, plus language-specific skills auto-loaded from the session-start context (e.g., `go/error-handling`, `go/style`, `go/context`, `go/concurrency`, `go/database`).

If a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the single entry in session-start `active_specs`), pass it as context to the agent. If two or more specs are in progress and no slug is provided, the spawned agent reports `needs-input` asking which spec applies.

Build and run affected tests before reporting done.
