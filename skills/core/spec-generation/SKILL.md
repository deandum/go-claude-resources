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

1. **Create spec directory** — Derive a kebab-case slug from the task. Create `docs/specs/<slug>/` by copying every file from `references/` into it.
2. **Clarify + ground** — Spawn `critic` and `scout` in parallel. Critic writes `critique.md` (gaps, XY problems, scope hazards). Scout writes `discovery.md` (existing code, patterns, gotchas).
3. **Pre-spec findings review** — Present the raw findings to the user as a `needs-input` report (one-line bullets per finding). User approves, corrects specific bullets, or stops. **Do not synthesize the spec until findings are approved.** This is the first cognitive-load checkpoint and costs the user seconds, not minutes.
4. **Scope** — Define what's in and explicitly what's out
5. **Surface assumptions** — List every assumption for user validation; scout's findings upgrade assumptions to "validated against codebase"
6. **Plan groups** — Break into atomic subtasks with dependencies. Tasks within a group run in parallel; groups run sequentially.
7. **Define boundaries** — Always do / Ask first / Never do
8. **Set success criteria** — Testable, measurable, verifiable evidence
9. **Populate spec.md** — Fold approved findings into the template. Frontmatter starts at `status: draft`, `current_group: 0`.
10. **Get approval** — Present `spec.md` to user. Do NOT proceed without sign-off. On approval, update frontmatter `status: approved` and record the decision in `group-log.md` Group 0.

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

### Group 1: [description] (parallel)
- [ ] **[agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Group 2: [description] (depends on Group 1)
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
- **Commands**: Exact commands with flags. Not "run tests" — give the full command with every flag spelled out.
- **Boundaries**: Three tiers prevent ambiguity. "Ask first" is for judgment calls.
- **Success Criteria**: Every criterion must be verifiable with a command or observable evidence. "Works correctly" is NOT a criterion. "GET /api/v1/orders returns 200 with order list" IS.

## Spec Directory Layout

Specs live under `docs/specs/<slug>/` as a directory of four artifacts. Lead creates the directory by copying every file from this skill's `references/` subdirectory into place at the start of Step 7.

| File | Owner | Lifecycle |
|------|-------|-----------|
| `spec.md` | lead | The contract. Created in Step 7, approved in Step 8, frontmatter evolves across groups. |
| `discovery.md` | scout | Written in Step 1 (parallel with critic). Frozen after Group 0 approval. |
| `critique.md` | critic | Written in Step 1 (parallel with scout). Frozen after Group 0 approval. |
| `group-log.md` | lead | Append-only. Group 0 records spec approval; Group N records group completion + user sign-off. |

### Frontmatter on `spec.md`

```yaml
---
task: <slug>
status: draft|approved|in-progress|complete|blocked
current_group: 0|1|...|done
total_groups: <int>
created: <ISO-8601 date>
updated: <ISO-8601 date>
---
```

- `status` is the enum; no other values are valid
- `current_group` is an integer in `[0, total_groups]` or the literal `done`
- `updated` changes every time the spec or group-log is touched

### Per-group sign-off protocol

After each group completes, lead emits a `needs-input` report (see [docs/agent-reporting.md](../../../docs/agent-reporting.md)) summarizing the group and asking: `"Approve group N and proceed to group N+1? (reply 'approve', 'changes: <what>', or 'stop')"`. On `approve`, lead records the decision in `group-log.md`, updates frontmatter `current_group`, and spawns the next group. On `changes`, lead updates the spec and re-runs affected tasks. On `stop`, lead sets `status: blocked` and halts.

No new vocabulary — group-review pauses reuse the existing `needs-input` status from the agent-reporting schema.

### Resumption

A session that ends mid-execution leaves the spec directory in a recoverable state. `session-start.sh` scans `docs/specs/*/spec.md` and emits an `active_specs` JSON field listing any spec whose `status != complete`. The lead agent reads this field on its first prompt of a new session and offers to resume via `/orchestrate --resume <slug>`. On resume, lead validates `current_group` against `group-log.md` and restarts at the next pending group.

### Template files and the core-skills convention

Core skills normally ship without supporting files (see [CLAUDE.md](../../../CLAUDE.md) → Naming). This skill is an exception: the four templates under `references/` are load-bearing content that exceeds the ~100-line ceiling for inline embedding, and every `/define` invocation depends on them. The exception is justified because the alternative — embedding the templates in `SKILL.md` itself — would push this file past the anatomy's concision rule.

Pair with: `core/discovery`, `core/skill-discovery`.

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

- [ ] `docs/specs/<slug>/` exists with all four artifacts: `spec.md`, `discovery.md`, `critique.md`, `group-log.md`
- [ ] `spec.md` frontmatter has all six fields (`task`, `status`, `current_group`, `total_groups`, `created`, `updated`)
- [ ] `spec.md` covers all template sections (no skipped sections)
- [ ] Assumptions explicitly stated; scout's Handoff items are marked "validated against codebase"
- [ ] Success criteria are testable (each can be verified with a command or observation)
- [ ] Boundaries have items in all three tiers
- [ ] Subtasks are atomic (one agent, one sentence, one acceptance criterion)
- [ ] Commands are exact (copy-paste runnable)
- [ ] `group-log.md` Group 0 records the user's spec approval
- [ ] User has approved the spec before implementation begins
