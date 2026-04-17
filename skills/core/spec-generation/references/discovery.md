---
task: <slug>
created: <ISO-8601 date>
---

# Discovery: [Task Title]

Written by `scout`. Grounds the spec in the existing codebase. Every claim cites a file path.

## Existing Surface

Files, packages, and functions already in the codebase that relate to this task. One row per entry.

| Path | Relevance |
|------|-----------|
| `path/to/file.go:42` | [what it does, why it matters for this task] |

## Patterns to Follow

Conventions observed in similar features. Cite an example for each pattern.

- **[Pattern name]** — [what the convention is]. Example: `path/to/example.go:NN`.

## Inherited Gotchas

Constraints, bugs, or surprising behavior that the spec must account for. From `recent_learnings` in session context or observed during scout exploration.

- [Gotcha] — evidence at `path/to/evidence`.

## Handoff to main Claude

What main Claude should fold into the spec's Assumptions and Technical Approach sections during spec synthesis.

- [Assumption] — already validated against codebase.
- [File to add to Technical Approach] — `path/to/file`, action: [modify|create].
