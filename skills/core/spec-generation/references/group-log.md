---
task: <slug>
created: <ISO-8601 date>
---

# Group Log: [Task Title]

Append-only. Lead writes one section per completed group. Resumption reads this file to confirm the last completed group before advancing `current_group` in `spec.md` frontmatter.

## Group 0: Spec approval

- **Status**: pending
- **Presented**: <ISO-8601 timestamp>
- **User decision**: <approve | changes: ... | stop>
- **Timestamp**: <ISO-8601 timestamp>
- **Notes**: _None._

<!--
Each group after 0 follows this shape:

## Group N: [short description]

### Task summary
| Task | Agent | Status | Files | One-line summary |
|------|-------|--------|-------|------------------|
| add GetByEmail | builder | complete | pkg/service/user.go | +42 lines, wraps repo errors with context |
| write tests for GetByEmail | tester | complete | pkg/service/user_test.go | 4 table-driven cases, all pass |

Task summary is the cognitive-load anchor — one line per task, signal first. Full per-task reports live in session context, not in this file.

### Mini-review findings
- **Critical**: _None._
- **Important**: _None._
- **Suggestions**: _None._

(When severity is Critical or Important, lead cannot advance past this group without explicit user acceptance.)

### User decision
- <approve | changes: ... | stop>
- **Timestamp**: <ISO-8601 timestamp>
- **Notes**: _None._

-->
