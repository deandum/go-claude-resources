---
description: Propose candidate invariants for docs/constitution.md from codebase evidence
---

Load the `core/constitution` skill — specifically the "Proposing Candidates" section — and drive the workflow from main Claude. Do NOT spawn a `lead` subagent.

Optional focus area: $ARGUMENTS  (e.g. "security", "observability"; empty = full survey)

This is NOT spec generation; skip `spec.md`.

Workflow:

1. Create `docs/specs/constitution-proposal/` (no spec.md; just `discovery.md` and `candidates.md`).
2. Spawn `critic` and `scout` in parallel, briefed per the skill's "Proposing Candidates" section:
   - Scout surveys the codebase for invariant-worthy patterns → `discovery.md`
   - Critic reads `discovery.md` and proposes 3–10 candidates → `candidates.md`
3. Synthesize a user-facing summary via `AskUserQuestion` and wait for a reply of the form `accept: [ids]` / `edit: <id>: <text>` / `reject: [ids]` / `stop`.
4. On approval, append accepted/edited invariants to `docs/constitution.md` (create the file with the frontmatter shape from `EXAMPLE_CONSTITUTION.md` if absent).

Do not write to `docs/constitution.md` without explicit user approval of each candidate.
