---
description: Write and run tests for the codebase
---

## Task

Spawn the `tester` agent with this task: $ARGUMENTS

The tester has `core/testing` loaded plus language-specific testing skills from session-start context (e.g., `go/testing`, or `go/testing-with-framework` if the project uses Ginkgo/Gomega).

Run tests with race detection (where available) after writing.
Fix failures before reporting done.
