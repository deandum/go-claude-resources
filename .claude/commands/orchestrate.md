---
description: Decompose a complex task and delegate to specialist agents
---

## Task

Spawn the `lead` agent with this task: $ARGUMENTS

The lead agent has the `core/spec-generation` skill and the `Agent` tool for delegation.

If `$ARGUMENTS` begins with `--resume <slug>`, lead resumes the in-progress spec at `docs/specs/<slug>/` — it reads the spec frontmatter, confirms the last completed group from `group-log.md`, and restarts at the next pending group. Any other shape of `$ARGUMENTS` is a fresh task.

Workflow (fresh task):
1. Lead spawns the `critic` and `scout` agents in parallel — critic clarifies, scout grounds in existing code
2. Lead creates `docs/specs/<slug>/` and synthesizes `spec.md` from critique + discovery, organizing subtasks into execution groups
3. User approves `spec.md` (Group 0 sign-off)
4. Lead executes groups — one agent per subtask, parallel within groups:
   - `architect` for structure/design
   - `builder` for implementation
   - `cli-builder` for CLI work
   - `tester` for tests
   - `reviewer` for review
   - `shipper` for deployment
5. **After each group, lead pauses for explicit sign-off** via a `needs-input` report — user replies `approve`, `changes: <what>`, or `stop`
6. Lead verifies results against spec success criteria after the final group

The spec IS the prompt for each agent. Do not start without user approval. Do not advance past a group without sign-off.
