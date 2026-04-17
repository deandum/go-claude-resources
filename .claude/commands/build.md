---
description: Implement application code following established patterns
---

Two operating modes:

**In-orchestration mode**: if a spec directory exists at `docs/specs/<slug>/spec.md` (slug from `$ARGUMENTS` or the sole `active_specs` entry) with `status: approved` or `in-progress`, load the `core/orchestration` skill and resume Phase 3 for the next pending group. Follow Steps 8–13 — spawn builder/cli-builder/shipper with self-contained prompts, run mini-review, gate via `AskUserQuestion`. Do not advance two groups without a gate.

**Ad-hoc mode**: if no spec matches, spawn the `builder` agent (or `cli-builder` for CLI commands/flags/config) directly with a self-contained prompt derived from `$ARGUMENTS`. The agent reports using the Agent Reporting schema. You summarize the result to the user. No gates.

If two or more specs are in-progress and `$ARGUMENTS` doesn't name one, ask the user which spec applies.

Task: $ARGUMENTS
