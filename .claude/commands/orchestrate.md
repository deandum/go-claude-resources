---
description: Decompose a complex task and delegate to specialist agents
---

Load the `core/orchestration` skill. You — the main Claude — are the lead. Do NOT spawn a `lead` subagent.

Apply the full workflow (Phases 1 through 4, Gates 1 through 3) to this task: $ARGUMENTS

If `$ARGUMENTS` begins with `--resume <slug>`, use the orchestration skill's Resumption section instead of starting fresh.

Every phase boundary is an `AskUserQuestion` gate. No auto-advance. `docs/specs/<slug>/group-log.md` is the audit trail.
