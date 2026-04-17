---
name: spec-generation
description: >
  Artifact contract for docs/specs/<slug>/ — spec.md template, frontmatter
  schema (task/status/current_group/total_groups/created/updated), spec
  directory layout, contracts-trigger rules, and parallelization markers
  ([P]). Load this skill whenever you're creating a new docs/specs/<slug>/
  directory, authoring or editing spec.md, checking whether an existing spec
  matches the template (e.g., during review, resumption, or session-start
  scan), validating frontmatter values, or deciding whether a task needs
  contracts.md. Pair with core/orchestration, which owns the workflow that
  populates these artifacts.
---

# Spec Generation

Defines the on-disk shape of a spec directory. The workflow that produces these artifacts lives in `core/orchestration`; this skill is the artifact contract.

## When to Use

- Creating a new `docs/specs/<slug>/` directory.
- Validating that an existing spec directory matches the template contract.
- Pair with `core/orchestration` — that skill owns the phases and gates that populate the artifacts defined here.

## When NOT to Use

- Deciding *whether* to spec a task — that's the `core/orchestration` "When to Use" decision.
- Running a spec-driven workflow — load `core/orchestration` instead. This skill is a contract, not a process.

## Spec Template

Every spec uses this exact structure. Downstream agents — builder, tester, reviewer — consume `spec.md` literally; a skipped section becomes a skipped requirement, and a reshuffled section becomes a confused subagent. The template is a contract, not a suggestion:

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

<!-- [P] = parallel-safe with siblings. Every task carries [P]; if a task is not parallel-safe, move it to its own group. -->

### Group 1: [description] (parallel)
- [ ] **[P] [agent]** — [one-sentence task description]
  - Files: [specific files]
  - Done when: [acceptance criterion]

### Group 2: [description] (depends on Group 1)
- [ ] **[P] [agent]** — [one-sentence task description]
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
- **Subtasks**: One agent per task. Each task completable in isolation. Each has acceptance criterion. Every task carries a `[P]` marker declaring it parallel-safe with its siblings — reviewer can audit that claim against the file list.
- **Commands**: Exact commands with flags. Not "run tests" — give the full command with every flag spelled out.
- **Boundaries**: Three tiers prevent ambiguity. "Ask first" is for judgment calls.
- **Success Criteria**: Every criterion must be verifiable with a command or observable evidence. "Works correctly" is NOT a criterion. "GET /api/v1/orders returns 200 with order list" IS.

### Parallelization Markers

The `[P]` prefix on every subtask declares "this task is safe to run simultaneously with every other task in this group." It encodes what the framework already does — groups are the unit of parallelism, tasks within a group are fanned out — but makes the safety claim auditable.

- If a task cannot be marked `[P]` (it reads files another task in the group writes, or it mutates shared state), split it into its own group.
- The marker appears before the agent name: `**[P] builder**`, `**[P] tester**`, etc.
- Reviewer checks markers during mini-review by cross-referencing the `Files:` line on each task — overlapping writes in the same group with `[P]` markers is a Critical finding.

## Spec Directory Layout

Specs live under `docs/specs/<slug>/` as a directory of four required artifacts plus one optional artifact. The orchestration workflow creates the directory by copying the four required templates from this skill's `references/` subdirectory. The fifth template (`contracts.md`) is copied conditionally — see the trigger rule below.

| File | Owner | Purpose |
|------|-------|---------|
| `spec.md` | main Claude | The contract. Frontmatter evolves across phases; sections remain stable. |
| `discovery.md` | scout | Prior art and gotchas. Frozen after Gate 1 approval. |
| `critique.md` | critic | Gaps, XY problems, scope hazards. Clarifying Questions resolved at Gate 1 fold into spec Assumptions. |
| `group-log.md` | main Claude | Append-only audit trail. Records spec approval, every group's completion, every gate's user reply. |
| `contracts.md` | architect | Optional. Copied when the task is API/data-heavy. Populated by architect after spec approval. |

### Contracts trigger

Scan the task description for any of these markers: `REST`, `gRPC`, `endpoint`, `handler`, `schema`, `webhook`, `event`, `message`, `payload`, `DB table`, `migration`, `API`. If any are present, copy `contracts.md` into the spec directory alongside the four required artifacts. If none are present, omit it — the spec directory has four artifacts.

When unsure, surface the ambiguity as a clarification question during Gate 1: "This spec may involve an HTTP/data contract. Copy contracts.md? (yes/no)".

After `spec.md` is approved, if `contracts.md` exists and is still the raw template, the orchestration workflow spawns `architect` to populate it. Reviewer validates implementation against `contracts.md` during mini-review — mismatches are Critical findings.

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

### Template files and the core-skills convention

Core skills normally ship without supporting files (see [CLAUDE.md](../../../CLAUDE.md) → Naming). This skill is an exception: the five templates under `references/` (`spec.md`, `discovery.md`, `critique.md`, `group-log.md`, and the conditional `contracts.md`) are load-bearing content that exceeds the ~100-line ceiling for inline embedding, and every `/define` invocation depends on them. The exception is justified because the alternative — embedding the templates in `SKILL.md` itself — would push this file past the anatomy's concision rule.

## Pair With

- `core/orchestration` — the workflow that produces these artifacts. This skill is the artifact contract; orchestration is the process.
- `core/constitution` — when the project has enforceable invariants, main Claude mirrors `critical` invariants into the spec's `Boundaries > Never do` tier verbatim during synthesis.
- `core/discovery` — scout's skill for populating `discovery.md`.
- `core/skill-discovery` — routing between skills per task.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I'll skip a template section, the caller knows what I mean" | Agents consume spec.md literally. Missing sections become missed requirements. |
| "Frontmatter is optional for small specs" | Resumption depends on frontmatter. No frontmatter → session-start can't detect the spec. |
| "I'll mark it `[P]` and sort out parallel-safety later" | `[P]` is an auditable claim. Lying about it produces races in mini-review. |
| "contracts.md is boilerplate, I'll leave it as the template" | The raw template triggers architect at Gate 2. Leaving it unpopulated blocks execution. |

## Red Flags

- Frontmatter missing any of the six required fields (`task`, `status`, `current_group`, `total_groups`, `created`, `updated`).
- `status` value outside the enum `{draft, approved, in-progress, complete, blocked}`.
- Subtask without a `[P]` marker — the parallel-safety claim must be explicit.
- `Commands` block with placeholders or missing flags — not copy-paste runnable.
- `Success Criteria` with unverifiable items ("works correctly") instead of testable ones.
- `Out of Scope` missing — scope ambiguity becomes scope creep.
- `contracts.md` present but left as the raw template after Gate 2 approval.

## Verification

Use these checks to validate an existing `docs/specs/<slug>/` matches the contract:

- [ ] `docs/specs/<slug>/` exists with the four required artifacts: `spec.md`, `discovery.md`, `critique.md`, `group-log.md`.
- [ ] If the task is API/data-heavy, `contracts.md` is also present and populated (not still the raw template).
- [ ] `spec.md` frontmatter has all six fields (`task`, `status`, `current_group`, `total_groups`, `created`, `updated`).
- [ ] `status` is one of `{draft, approved, in-progress, complete, blocked}`; no other value.
- [ ] `current_group` is an integer in `[0, total_groups]` or the literal `done`.
- [ ] `spec.md` covers every template section (Objective, Assumptions, Scope, Technical Approach, Subtasks, Commands, Boundaries, Success Criteria) with no skipped headings.
- [ ] Every subtask carries the `[P]` parallelization marker.
- [ ] Success criteria are testable (each verifiable with a command or observation).
- [ ] Boundaries have items in all three tiers (Always do / Ask first / Never do).
- [ ] Subtasks are atomic (one agent, one sentence, one acceptance criterion).
- [ ] Commands are exact (copy-paste runnable with all flags).
