---
description: Design architecture and project structure
---

## Task

Spawn the `architect` agent with this task: $ARGUMENTS

The architect has `core/project-structure` and `core/api-design` skills loaded, plus language-specific design skills from session-start context (e.g., `go/project-init`, `go/interface-design`, `go/api-design`, `go/modules`).

If a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the single entry in session-start `active_specs`), pass it as context so the architect can ground the design in the spec's Technical Approach.

Present the proposed design for user approval before generating any files.
