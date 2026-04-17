---
description: Write and run tests for the codebase
---

Spawn the `tester` agent directly with a self-contained prompt for: $ARGUMENTS

This is a standalone command — it does NOT enter the orchestration workflow. Use `/orchestrate` or `/build` if you want gated, spec-driven testing.

The tester's prompt must include the `Files:` list scoped to `*_test.*` paths, `Done when:` criterion, any relevant quoted context, and `Verify with:` (e.g., `go test -race ./pkg/foo`).

Tester runs tests with race detection. On any failure it returns `Status: needs-input` with failures listed in Blockers — it does NOT auto-fix. Surface the failures to the user verbatim; the user decides whether to investigate, fix, or stop.
