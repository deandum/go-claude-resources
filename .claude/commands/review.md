---
description: Review code for correctness, security, and quality
---

## Task

Spawn the `reviewer` agent with this task: $ARGUMENTS

The reviewer has `core/code-review` and `core/style` skills loaded, plus language-specific review skills from session-start context (e.g., `go/code-review`, `go/error-handling`, `go/concurrency`).

If a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the single entry in session-start `active_specs`), pass it as context so the reviewer can check the change against the spec's Boundaries and Success Criteria.

The reviewer is read-only — it reports findings but does not modify code.
Every finding must have a severity label: Critical, Important, Suggestion, Nit, or FYI.
