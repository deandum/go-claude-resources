---
description: Containerize and add observability for production
---

Two operating modes:

**In-orchestration mode**: if a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the sole `active_specs` entry) and contains shipper-tagged tasks, load the `core/orchestration` skill and resume Phase 3 for those tasks. Follow Steps 8–13.

**Ad-hoc mode**: if no active spec, spawn the `shipper` agent directly with a self-contained prompt for `$ARGUMENTS`. Shipper audits what exists, then adds in order: structured logging → health checks → metrics → Dockerfile. Reports using the Agent Reporting schema. You summarize to the user.

External-write actions (`docker push`, `kubectl apply`, registry push) require `ops_enabled=true` in session context. Default is local-only — shipper builds and verifies but does not push.

Task: $ARGUMENTS
