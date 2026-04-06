---
name: spec-generation
description: >
  Generate structured spec files for agent consumption. Use when
  decomposing tasks into actionable specs that builder/tester/reviewer
  agents can execute without interpretation.
---

# Spec Generation

Code without a spec is guessing. The spec surfaces misunderstandings before code — assumptions are the most dangerous form of misunderstanding.

## When to Use

- Multi-file or multi-package changes
- New features or new projects
- Ambiguous or complex requirements
- Any task exceeding 30 minutes of work
- When lead agent decomposes work for the team

## When NOT to Use

- Single-line fixes or typo corrections
- Self-contained changes to one function
- Tasks already specified with clear acceptance criteria

## Core Process

1. **Clarify** — Spawn critic to identify gaps, assumptions, and XY problems
2. **Scope** — Define what's in and explicitly what's out
3. **Surface assumptions** — List every assumption for user validation
4. **Plan waves** — Break into atomic subtasks with dependencies
5. **Define boundaries** — Always do / Ask first / Never do
6. **Set success criteria** — Testable, measurable, verifiable evidence
7. **Save spec** — Write to `SPEC-[task-slug].md` in project root
8. **Get approval** — Present to user. Do NOT proceed without sign-off.

## Spec Template

Every spec MUST use this exact structure:

```markdown
# Spec: [Task Title]

## Objective
[What we're building and why. 2-3 sentences max.]

## Assumptions
- [Assumption 1 — surface these upfront]
- [Assumption 2 — unstated assumptions are where bugs live]

## Scope

### In Scope
- [Concrete deliverable 1]
- [Concrete deliverable 2]

### Out of Scope
- [Explicitly excluded item 1]

## Technical Approach

### Files to Modify/Create
| File | Action | Purpose |
|------|--------|---------|
| `path/to/file` | Modify | [what changes and why] |
| `path/to/new` | Create | [what this adds] |

### Architecture Decisions
- [Decision: why this approach over alternatives]

## Subtasks

### Wave 1: [description] (parallel)
- [ ] **[agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Wave 2: [description] (depends on Wave 1)
- [ ] **[agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

## Commands
\```bash
# Build
[exact build command with all flags]
# Test
[exact test command with all flags]
# Lint
[exact lint command with all flags]
\```

## Boundaries

### Always do
- [action allowed without asking]

### Ask first
- [high-impact change requiring approval]

### Never do
- [hard stop — never cross this line]

## Success Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] All tests pass
- [ ] Build succeeds
- [ ] No new linting errors
```

## Template Rules

- **Objective**: 2-3 sentences. State what AND why. No jargon.
- **Assumptions**: If you're assuming something, say it. Better to be wrong early than wrong in production.
- **Scope**: "Out of Scope" prevents scope creep. Be explicit.
- **Files table**: Exact paths. Agents execute literally — ambiguity becomes errors.
- **Subtasks**: One agent per task. Each task completable in isolation. Each has acceptance criterion.
- **Commands**: Exact commands with flags. Not "run tests" — `go test -race -v ./...`
- **Boundaries**: Three tiers prevent ambiguity. "Ask first" is for judgment calls.
- **Success Criteria**: Every criterion must be verifiable with a command or observable evidence. "Works correctly" is NOT a criterion. "GET /api/v1/orders returns 200 with order list" IS.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "It's obvious, no spec needed" | Obvious to you isn't obvious to agents. Specs surface misunderstandings before code. |
| "I'll write the spec after coding" | That's documentation, not specification. Value is in forcing clarity before code. |
| "The spec will slow us down" | A 15-minute spec prevents hours of rework. Debugging is slower than specifying. |
| "Requirements are still changing" | Specs can change too. A wrong spec is easier to fix than wrong code. |

## Red Flags

- Vague requirements accepted without pushback ("make it better")
- No acceptance criteria — no way to know when you're done
- Missing "Out of Scope" — everything is in scope, which means nothing is
- Commands without flags — agents will guess wrong
- "Ask first" tier is empty — means every boundary is either always or never, which is unrealistic
- Success criteria that can't be verified with a command

## Verification

- [ ] Spec covers all template sections (no skipped sections)
- [ ] Assumptions explicitly stated and validated with user
- [ ] Success criteria are testable (each can be verified with a command or observation)
- [ ] Boundaries have items in all three tiers
- [ ] Subtasks are atomic (one agent, one sentence, one acceptance criterion)
- [ ] Commands are exact (copy-paste runnable)
- [ ] User has approved the spec before implementation begins
