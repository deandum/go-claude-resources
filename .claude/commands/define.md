---
description: Analyze task requirements and generate a structured spec
---

Use the critic agent first to analyze this task. Read relevant code.
Challenge requirements for clarity, completeness, and feasibility.
Surface all assumptions explicitly. Identify XY problems and scope creep.

Then use the lead agent to generate a structured spec file (SPEC-[task-slug].md)
following the spec-generation skill template. The spec must include:
Objective, Assumptions, Scope, Technical Approach, Subtasks (in waves),
Commands, Boundaries (always/ask-first/never), and Success Criteria.

Present the spec to me for approval before any implementation begins.
