---
task: <slug>
status: draft
current_group: 0
total_groups: 0
created: <ISO-8601 date>
updated: <ISO-8601 date>
---

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

### Group 1: [description] (parallel)
- [ ] **[agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Group 2: [description] (depends on Group 1)
- [ ] **[agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

## Commands
```bash
# Build
[exact build command with all flags]
# Test
[exact test command with all flags]
# Lint
[exact lint command with all flags]
```

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
