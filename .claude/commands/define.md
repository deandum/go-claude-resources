---
description: Analyze task requirements and generate a structured spec
---

## Task

Spawn the `lead` agent with this task: $ARGUMENTS

The lead agent has the `core/spec-generation` skill loaded and will:
1. Spawn the `critic` and `scout` agents in parallel — critic challenges the request, scout grounds it in existing code
2. Create `docs/specs/<slug>/` by copying templates from `skills/core/spec-generation/references/`
3. Synthesize critic's `critique.md` and scout's `discovery.md` into `spec.md`
4. Present `spec.md` for user approval before any execution (Group 0 sign-off)

Do not proceed to implementation without explicit user approval of the spec.
If the task is too vague even for a spec, suggest running `/ideate` first.
