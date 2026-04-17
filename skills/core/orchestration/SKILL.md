---
name: orchestration
description: >
  Spec-driven development workflow. Main Claude acts as the lead — spawns
  critic/scout/architect/builder/tester/reviewer as subagents, enforces
  human-in-the-loop gates at every phase boundary via AskUserQuestion,
  records every decision in docs/specs/<slug>/group-log.md. Load this skill
  whenever the user invokes /define, /orchestrate, /plan, /build, or /ship;
  whenever a task spans multiple files, packages, or concerns; whenever design
  decisions need review before implementation; whenever an in-progress spec
  under docs/specs/<slug>/ needs to resume; or whenever you're about to
  coordinate critic/scout/architect/builder/tester/reviewer in a sequence.
  This is the correct skill for any multi-step engineering task that benefits
  from gated, auditable execution — do not try to coordinate specialists ad-hoc.
---

# Orchestration

Spec-driven workflow. Main Claude drives; specialists execute bounded work; the user gates every phase boundary.

## When to Use

- Any of `/define`, `/orchestrate`, `/plan`, `/build`, `/ship` is invoked.
- Task spans multiple files, packages, or concerns.
- Design decisions need review before implementation.

## When NOT to Use

- Single-line typos, trivial edits, pure exploration.
- Read-only questions about the codebase.
- One-file changes with no design question.
- `/test` and `/review` as standalone commands — they spawn tester/reviewer directly without entering this workflow.

## Core Principle

You — the main Claude — are the lead. You do NOT spawn a `lead` subagent. Spawning `lead` as a subagent was the structural bug this skill replaces.

You own:
- Every file write under `docs/specs/<slug>/`.
- Every user-facing gate (via `AskUserQuestion`).
- The state machine — `spec.md` frontmatter + append-only `group-log.md`.
- Synthesis of subagent reports into the group log.

You spawn subagents only for bounded work, always with a targeted, self-contained prompt (never "read spec.md and figure it out"):

| Phase | Subagent | Purpose |
|---|---|---|
| 1 | critic | Challenges requirements, writes `critique.md` |
| 1 | scout | Grounds spec in existing code, writes `discovery.md` |
| 2 | architect | (Optional) Populates `contracts.md` for API/data tasks |
| 3 | builder, cli-builder, shipper | Implementation, one task each |
| 3 | tester | Tests, one task each |
| 3 | reviewer | Mini-review after each group; final review at end |

Subagents never spawn subagents. You never write application code.

## Phase 1 — Analysis

**Step 1.** Derive a kebab-case slug from the task. Create `docs/specs/<slug>/` by copying the four required templates from `skills/core/spec-generation/references/` (`spec.md`, `discovery.md`, `critique.md`, `group-log.md`). Copy `contracts.md` only if the task text contains any of the API/data markers defined in `core/spec-generation` Contracts trigger.

**Step 2.** Spawn `critic` and `scout` in a single assistant turn (two `Agent` tool calls in the same message; the framework runs them in parallel). Each subagent gets the full task text. If session-start context has `project_constitution` non-empty, quote the invariant list verbatim in the critic prompt under a header `Project invariants:` — critic surfaces any spec direction that would violate a `critical` invariant as `Blocker: yes`, regardless of which agent is nominally responsible for enforcement. Wait for both to return.

**Step 3. (Gate 1 — findings review.)** Present findings in a fixed two-section format so the user can see what each agent found without deduplication:

```
## Scout findings (discovery.md)
- <one-line bullet per Existing Surface / Pattern / Gotcha>

## Critic findings (critique.md)
- <one-line bullet per Gap / XY Problem / Scope Hazard>

## Clarifying questions (Blocker: yes)
- <each question with suggested default>  [omit section if none]
```

Then invoke `AskUserQuestion`:

- Question: `"Approve scout + critic findings for <slug>?"`
- Options: `approve` / `correct: <bullet>` / `stop`

Do NOT write `spec.md`. Do NOT spawn other agents. On `correct`: edit the relevant artifact, re-present, re-gate. On `stop`: set `status: blocked` and halt.

**Step 4. (Clarification round-trip, optional.)** If `critique.md` has any `Blocker: yes` clarifying questions, resolve each via `AskUserQuestion` (critic's suggested default as first option). Append resolutions to `critique.md` under `## Resolutions`. Fold accepted answers into `spec.md` Assumptions during synthesis with the tag `(from clarification)`.

## Phase 2 — Spec Generation

**Step 5.** Synthesize `spec.md` from approved findings. Populate every template section (Objective, Assumptions, Scope, Technical Approach, Subtasks, Commands, Boundaries, Success Criteria). Frontmatter: `status: draft`, `current_group: 0`, `total_groups: <count>`, `created`/`updated: <ISO-8601>`.

**Step 6. (Gate 2 — spec approval.)** `AskUserQuestion`:

- Question: `"Approve spec.md for execution?"`
- Options: `approve` / `changes: <what>` / `stop`

On `approve`: set `status: approved`, append "Group 0: Spec approval" entry to `group-log.md` with timestamp and the user's verbatim reply. On `changes`: edit the spec, re-present. On `stop`: set `status: blocked`.

**Step 7.** If `contracts.md` exists and is still the raw template, spawn `architect` with a self-contained prompt — do not simply point at the files. The prompt MUST include:

- The approved spec's `Technical Approach` section verbatim
- The approved spec's `Success Criteria` section verbatim
- Scout's `Handoff to main Claude` items as a bullet list (copied from `discovery.md`)
- Explicit instruction: "Populate every section of `contracts.md` (Endpoints, Request Schemas, Response Schemas, Error Codes, Events, Data Invariants). Flag any gap in your report's Follow-ups rather than guessing."
- File to write: `docs/specs/<slug>/contracts.md`

Architect returns `needs-input`. Present populated contracts via a second `AskUserQuestion` gate before Phase 3. Same options as Gate 2 (`approve` / `changes: <what>` / `stop`). Record the decision in `group-log.md` as "Group 0b: Contracts approval" with timestamp.

## Phase 3 — Execution (one group at a time)

**Zero-group specs.** If `total_groups: 0` (a spec that only changes policy, docs, or otherwise has no builder work), skip Steps 8–13 entirely. Append a "Group 0c: Zero-group spec — skipping execution" entry to `group-log.md` and proceed to Phase 4. This is valid for spec-only changes; reviewer still runs Phase 4's Commands block if any.

For each group N in `spec.md` (from 1 to total_groups), in order:

**Step 8.** Update `spec.md` frontmatter: `status: in-progress`, `current_group: N`, `updated: <ISO-8601>`.

**Step 9.** For each task in group N, spawn exactly one subagent with a **self-contained prompt**. The prompt MUST include:

- One-sentence task description
- `Files:` line from the spec (exact paths)
- `Done when:` acceptance criterion
- Relevant architecture decisions quoted verbatim (NOT referenced by path)
- Pattern to follow (file:line of prior art, if applicable)
- Specific verify command (e.g., `go test ./pkg/foo`, `go vet ./...`)

Do NOT pass "read `docs/specs/<slug>/spec.md`" as the whole prompt. Extract the slice. Reason: each subagent starts with an empty context. Pointing at `spec.md` forces every subagent to re-read the whole file, costs tokens, and invites the subagent to reinterpret decisions already settled. Quoting the relevant decisions verbatim in the prompt costs you one `Edit`-style copy-paste but gives the subagent an unambiguous contract it can't drift from.

Tasks within a group carry `[P]` and may be spawned in parallel (single assistant message, multiple `Agent` tool calls). Groups never overlap.

**Step 10.** Collect reports. Handle each status. One `needs-input` or `blocked` subagent pauses the whole group — do NOT run the mini-review (Step 11) with partial results. The completed tasks' work stays on disk; the group-log records them as complete so resumption knows what's done.

- `complete` — Verify `Files touched` matches the task's `Files:` line. Any file written outside the declared `Files:` scope is a Critical finding for the mini-review (the spec is the contract; silent scope creep erodes it). Cite the unexpected path explicitly.
- `needs-input` — Do NOT auto-resolve. Surface the subagent's blockers to the user via `AskUserQuestion` with the subagent's own message verbatim in the question body. The common sub-cases and their resolution paths:
  - **Prompt missing a field** (builder/tester couldn't find `Files:` or `Verify with:`) — options: `re-spawn with fix` / `stop`. On re-spawn, main Claude composes a complete prompt and re-issues.
  - **Test failure** (tester returned failing tests) — options: `revise spec` / `re-run tester with note: <investigation path>` / `stop`. Tester cannot write to application files; if the fix requires app-code changes, user must pick `revise spec`, main Claude updates the spec (see revision procedure below), and the next builder spawn addresses it.
  - **Scope revision needed** (builder says additional files must change) — trigger the mid-Phase-3 revision procedure: pause group, surface the required changes, on approval append `_revision_N_` note to `spec.md` with timestamp and reason, update the `Files:` line, re-gate via `AskUserQuestion` `"Approve revised Files list and re-run task?"`, then re-spawn the affected task(s). Do not advance `current_group` during revision. Record the revision in `group-log.md` under the current Group's section.
- `blocked` — Something the subagent can't resolve (app code broken, missing dependency). Surface verbatim as above. Options: `stop` / `fix out-of-band and retry` / `revise spec`. Do not spawn more tasks in this group until resolved.

**Step 11.** Spawn `reviewer` in mini-review mode. The prompt MUST include:

- `Files:` — the explicit list of files changed by this group (union of all tasks' reports)
- `Verify with:` — the exact commands lifted from the spec's `Commands` block (build, test, vet; include all flags)
- `Scope:` — the group number and a one-line description

Reviewer runs the verify commands directly and captures exit codes. A failing build or test is a Critical finding regardless of code-review verdict. The first run on a new machine may trigger permission prompts from Claude Code — users approve once per command pattern; that friction is one-time, not a framework bug.

**Step 12.** Append "Group N" section to `group-log.md` with:

- Task summary table (one line per task — agent, status, files, 3-line summary)
- Mini-review findings (Critical / Important counts + citations)
- ISO-8601 timestamp

**Step 13. (Per-group gate.)** `AskUserQuestion`:

- Question: `"Approve Group N and proceed to Group N+1?"` — include the Critical/Important counts in the question body
- Options: `approve` / `changes: <what>` / `stop`

If Critical or Important findings exist, the question body highlights them. Do NOT auto-approve. On `approve`: record in `group-log.md`, advance `current_group`. On `changes`: re-run affected tasks, re-present. On `stop`: set `status: blocked`.

Repeat Steps 8–13 for every group.

## Phase 4 — Final Verification

**Step 14.** Run the spec's `Commands` block (build, test, lint) directly. Report pass/fail for each with the exact command output.

**Step 15.** Walk each `Success Criteria` bullet. Mark pass/fail with evidence (command output, file:line, diff hunk).

**Step 16. (Gate 3 — final.)** `AskUserQuestion`:

- Question: `"Approve final verification? (pass: X/Y criteria)"`
- Options: `approve` / `changes: <what>` / `stop`

On `approve`: set `status: complete`, `current_group: done`, `updated: <ISO-8601>`. Append "Verification" entry to `group-log.md`.

## Resumption

Session-start emits `active_specs` as a comma-joined list of `<slug>:<current_group>/<total_groups>` pairs. On any fresh user turn where `active_specs` is non-empty and the user did not name a slug:

1. **Single active spec.** Surface via `AskUserQuestion`: `"Detected in-progress spec <slug> at group N/M (status: <status>, last sign-off <timestamp>). Resume, ignore, or mark blocked?"`
2. **Multiple active specs.** Surface one `AskUserQuestion` per spec with options `resume` / `ignore` / `mark blocked`, or collapse into a single question where each spec is one option label (`resume <slug-a>` / `resume <slug-b>` / `ignore all and start new`). Only one spec can be actively resumed in a session — if the user picks `resume` for two, ask a follow-up to pick one to resume now; the other stays in-progress.
3. On `resume`: read `spec.md` frontmatter. Valid resume states and actions:
   - `approved` — start Phase 3 from `current_group: 1`
   - `in-progress` — continue Phase 3 from `current_group` as recorded
   - `draft` — Phase 2 never completed. Re-present via Gate 2 before any execution.
   - `blocked` — ask the user to clear the blocker first (show the `group-log.md` entry that recorded it). Once cleared, user explicitly resumes.
   - `complete` — report "already complete" and proceed with the new task.

   Then read `group-log.md`. For `in-progress`, confirm the last group entry matches `current_group - 1`; for `approved`, confirm the last entry is "Group 0: Spec approval" (or "Group 0b" / "Group 0c" variants). If the log disagrees with frontmatter, STOP and surface the drift via `AskUserQuestion` — do not guess which source of truth wins.
4. On `ignore`: proceed with the new task, leave active spec as-is.
5. On `mark blocked`: set `status: blocked`, record reason in `group-log.md` with ISO timestamp.

`/orchestrate --resume <slug>` follows the same protocol without the choice step — if the named slug is `draft` or `blocked`, surface that state rather than silently advancing.

## Out-of-Band Execution is a Bug

The #1 failure mode of the previous framework: the lead subagent wrote code directly during Phase 1/2, skipping gates. To prevent recurrence:

- **Phase 1 and Phase 2:** You may spawn only `critic`, `scout`, and (conditionally) `architect`. You may NOT write source code. You may NOT spawn `builder`, `cli-builder`, `tester`, or `shipper`.
- **Phase 3:** You spawn one group's subagents, then hit exactly one gate, then advance. Spawning two groups back-to-back without a gate is forbidden.
- If you catch yourself writing source code or advancing groups without a gate: STOP. Record the incident in `group-log.md` under a "Drift" subsection. Escalate to the user via `AskUserQuestion`.

## Audit Trail Requirements

Every gate decision → `group-log.md` entry:

- ISO-8601 timestamp
- Gate name (G1 findings, G2 spec, Group N, G3 final)
- User's reply text verbatim (including any `changes: <what>` payload)

Every subagent spawn → `group-log.md` entry:

- Task id (e.g., `3.1`)
- Agent name
- Files touched (from the report)
- Status (`complete` / `needs-input` / `blocked`)
- Summary (3 lines max)

Every spec revision post-approval:

- Append `_revision_N_` note to `spec.md` with ISO timestamp + reason (e.g., "Group 2 builder surfaced missing error-path handling")
- Revert frontmatter `status: draft`
- Leave `current_group` as-is — completed groups stay completed; the revision does NOT re-execute them
- Re-run Gate 2 before any further execution. On approval, set `status: in-progress` and resume at `current_group + 1` (or re-run the affected group if the revision changed that group's Files list, in which case `current_group` stays and the group re-executes per Step 10's revision procedure)

No silent mutations. No retroactive acceptance. The audit trail is the contract — it's what lets the user trust the work and a future session resume from a known state. A gap in the log is a gap in the contract.

## Subagent Prompt Template (Phase 3)

```
Task: <one sentence from spec>
Files: <exact paths from spec's Files row>
Acceptance: <done-when criterion>

Relevant decisions (quoted from spec, do not re-read):
- <decision 1 verbatim>
- <decision 2 verbatim>

Pattern to follow: <file:line of prior art, if applicable>

Verify with: <exact build/test command>

Report using the Agent Reporting schema (Status, Files touched, Evidence,
Follow-ups, Blockers).
```

The subagent does not need to read `spec.md`. Keep it narrow.

## Common Rationalizations

> "I'll just write this one file to save a round trip"

Reality: Out-of-band writes skip Gate 2 and the mini-review. That is the bug class this skill exists to prevent. Spawn the builder.

> "The group is small, one gate will cover two groups"

Reality: Gates are the HITL surface. Collapsing them defeats the point. One group → one gate.

> "The user already approved the design, I can just fix this small issue"

Reality: Spec revisions after approval require Gate 2 again. Otherwise the audit trail lies.

## Red Flags

- Main Claude wrote to a source file in Phase 1 or Phase 2.
- Two "Group N" entries in `group-log.md` without a gate entry between them.
- Mini-review logged as `"Critical: _None._"` but reviewer never ran build/test.
- Subagent prompt is "read `docs/specs/<slug>/spec.md`" with nothing else.
- `spec.md` frontmatter `status` doesn't match `group-log.md`'s last entry.
- Spec revision without a `_revision_N_` note or re-approval.
- Group-log task table shows `(direct)` in the Agent column — main Claude bypassed delegation.

## Verification Checklist

- [ ] Main Claude executed the workflow (not a subagent).
- [ ] `critic` + `scout` spawned in one message with two `Agent` calls.
- [ ] Gate 1 used `AskUserQuestion` before `spec.md` existed.
- [ ] Gate 2 used `AskUserQuestion` before any Phase 3 subagent ran.
- [ ] Per-group gate used `AskUserQuestion` after every group.
- [ ] No source code written during Phase 1 or Phase 2.
- [ ] No group started before the previous gate approved.
- [ ] Every Phase 3 subagent received a targeted, self-contained prompt.
- [ ] `group-log.md` has one entry per gate + one entry per subagent spawn.
- [ ] Build/test/lint in Phase 4 ran directly (no "user needs to run" deferral).
- [ ] Any post-approval spec revision forced a re-gate.

## Pair With

- `core/spec-generation` — owns the `docs/specs/<slug>/` template layout and frontmatter schema. This skill defines the workflow that produces those artifacts.
- `core/constitution` — loaded automatically when `project_constitution` is non-empty.
- `core/token-efficiency` — compress human-facing prose; never compress spec or group-log content.
