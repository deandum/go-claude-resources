---
description: Decompose a complex task and delegate to specialist agents
---

## Task

Spawn the `lead` agent with this task: $ARGUMENTS

The lead agent has the `core/spec-generation` skill and the `Agent` tool for delegation.

Workflow:
1. Lead spawns the `critic` agent to clarify and decompose
2. Lead generates `SPEC-[task-slug].md` with subtasks organized in execution waves
3. User approves the spec
4. Lead executes waves — one agent per subtask, parallel within waves:
   - `architect` for structure/design
   - `builder` for implementation
   - `cli-builder` for CLI work
   - `tester` for tests
   - `reviewer` for review
   - `shipper` for deployment
5. Lead verifies results against spec success criteria

The spec IS the prompt for each agent. Do not start without user approval.
