---
description: Analyze task requirements and generate a structured spec
---

Load the `core/orchestration` skill. You — the main Claude — are the lead. Do NOT spawn a `lead` subagent.

Run Phase 1 (Analysis — spawn critic + scout in parallel, Gate 1 findings review, optional Gate 1 clarification round-trip) and Phase 2 (Spec Generation — synthesize spec.md, Gate 2 approval). Stop after Gate 2 with `spec.md` frontmatter at `status: approved`.

Do NOT enter Phase 3. Execution is a separate user-invoked step (`/orchestrate --resume <slug>` or `/build`).

Task: $ARGUMENTS

If the task is too vague for a spec, suggest `/ideate` first.
