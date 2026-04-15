---
description: Containerize and add observability for production
---

## Task

Spawn the `shipper` agent with this task: $ARGUMENTS

The shipper has `core/docker` and `core/observability` skills loaded, plus language-specific deployment skills from session-start context (e.g., `go/docker`, `go/observability`).

If a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the single entry in session-start `active_specs`), pass it as context so the shipper can align container and observability work with the spec.

Audit what exists first. Then add in order:
1. Structured logging → 2. Health checks → 3. Metrics → 4. Dockerfile
Verify: build image, check size, test health endpoint.
