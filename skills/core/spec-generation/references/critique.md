---
task: <slug>
created: <ISO-8601 date>
---

# Critique: [Task Title]

Written by `critic`. Adversarial analysis — gaps, XY problems, scope hazards. Scout handles existing-code discovery; critic's job is to push back on the request itself.

## Gaps

What is missing from the task as stated? Unstated assumptions, missing acceptance criteria, undefined scope edges.

- [Gap] — the task assumes X but does not specify Y.

## XY Problems

Cases where the request asks for X but the underlying need is Y. Call out the X→Y mismatch and the real problem.

- [Request] "[stated X]" → [real problem] "[actual Y]"

## Scope Hazards

Where does scope want to creep? Where does the task straddle boundaries that should remain separate?

- [Hazard] — [what would expand scope if not contained].

## Handoff to lead

What lead should fold into the spec's Out of Scope, Boundaries, and Success Criteria sections.

- **Out of Scope**: [item] — rationale.
- **Ask first**: [action] — rationale.
- **Success Criteria edge case**: [condition] — must be verified before the task is complete.
