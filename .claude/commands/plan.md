---
description: Design architecture and project structure
---

Two operating modes:

**Contracts-population mode** (in-orchestration): if `docs/specs/<slug>/spec.md` exists at `status: approved` with `contracts.md` still the raw template, load the `core/orchestration` skill and run Phase 2 Step 7 — spawn `architect` with a self-contained prompt (quote the spec's Technical Approach + Success Criteria; include scout's Handoff items). Gate the populated `contracts.md` via `AskUserQuestion` before any Phase 3 work.

**Ad-hoc mode** (standalone): if no spec matches, spawn the `architect` agent directly for the design task in `$ARGUMENTS`. Architect proposes the design in its report's Evidence; you present the proposal to the user for approval before any files are generated.

Slug for contracts-population mode comes from `$ARGUMENTS` or the single `active_specs` entry. If two or more specs are in progress and no slug is named, ask the user which spec applies.

Task: $ARGUMENTS
