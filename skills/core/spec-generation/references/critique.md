---
task: <slug>
created: <ISO-8601 date>
---

# Critique: [Task Title]

Written by `critic`. Adversarial analysis — gaps, XY problems, scope hazards. Scout handles existing-code discovery; critic's job is to push back on the request itself.

## Gaps

What is missing from the task as stated? Unstated assumptions, missing acceptance criteria, undefined scope edges.

- [Gap] — the task assumes X but does not specify Y.

## Clarifying Questions

Every gap that cannot be resolved from task text + codebase becomes a question the user must answer before spec synthesis. Each question carries a suggested default so the flow stays fast when the default is acceptable. `Blocker: yes` means proceeding without an answer would make the spec silently wrong — main Claude pauses at Gate 1's clarification round-trip until these are resolved.

1. **Q:** [the question]
   **Suggested default:** [the answer to use if the user skips]
   **Blocker:** yes

2. **Q:** [the question]
   **Suggested default:** [the answer to use if the user skips]
   **Blocker:** no

<!-- If there are no clarifying questions, state "_None — every gap resolvable from task + codebase._" and omit the numbered list. -->

## XY Problems

Cases where the request asks for X but the underlying need is Y. Call out the X→Y mismatch and the real problem.

- [Request] "[stated X]" → [real problem] "[actual Y]"

## Scope Hazards

Where does scope want to creep? Where does the task straddle boundaries that should remain separate?

- [Hazard] — [what would expand scope if not contained].

## Handoff to main Claude

What main Claude should fold into the spec's Out of Scope, Boundaries, and Success Criteria sections during spec synthesis.

- **Out of Scope**: [item] — rationale.
- **Ask first**: [action] — rationale.
- **Success Criteria edge case**: [condition] — must be verified before the task is complete.
