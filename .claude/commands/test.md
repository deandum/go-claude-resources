---
description: Write and run tests for the codebase
---

## Task

Spawn the `tester` agent with this task: $ARGUMENTS

The tester has `core/testing` loaded plus language-specific testing skills from session-start context (e.g., `go/testing`, or `go/testing-with-framework` if the project uses Ginkgo/Gomega).

If a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the single entry in session-start `active_specs`), pass it as context so the tester knows the success criteria it must verify.

Run tests with race detection (where available) after writing.
If any test fails, the tester returns `needs-input` with the failures listed — it does NOT auto-fix. Surface the failures to the user and wait for direction.
