# Agent Reporting Protocol

How specialist agents return results to the `lead` agent (in multi-wave work) or directly to the user (in single-agent runs).

All code-writing and review agents — `builder`, `cli-builder`, `tester`, `reviewer`, `shipper`, `architect` — end their work with a structured report in this format. The `lead` agent parses each report and validates results against the spec's success criteria before spawning the next wave.

For the full per-agent role reference (tools, skills, when to use), see [agents.md](agents.md).

## Schema

Every report has these sections in order. Use them literally as headings.

### Status

One of:

- **`complete`** — task finished, acceptance criteria met, evidence attached
- **`blocked`** — cannot proceed without outside intervention; Blockers section mandatory
- **`needs-input`** — work done but a decision is required before finalizing (e.g., two viable designs, unclear spec)

### Files touched

A table. One row per file created, modified, or deleted.

| Path | Action | Summary |
|------|--------|---------|
| `pkg/service/user.go` | modified | added `GetByEmail` method |
| `pkg/service/user_test.go` | created | table-driven tests for `GetByEmail` |

If nothing on disk changed, write: `_None (read-only task)._`

### Evidence

Specific, verifiable proof the task is done. Prefer command output over prose.

```
$ go build ./...
(exit 0, no output)

$ go test ./pkg/service/... -race
ok  	example/pkg/service	0.203s
```

For review tasks, Evidence is the full review with severity labels.
For design tasks, Evidence is the proposed structure, interfaces, or architecture diagram.

### Follow-ups

Issues discovered during the task that are out of scope for this subtask but worth tracking. One bullet per item.

- spec gap: `FindByEmail` is documented but not specified
- adjacent bug: `UserRepository.Close` does not drain in-flight queries
- suggestion: rename `u` receiver to `s` to match surrounding service convention

Write `_None._` if nothing to report. Do not invent follow-ups to look thorough.

### Blockers

**Only when `status: blocked`.** Omit this section entirely otherwise.

State what stopped progress and what input is needed — one per bullet.

- "Need decision: should `GetByEmail` return `(User, bool)` or `(User, error)` for not-found?"
- "Test fixture `testdata/users.json` is missing — spec references it but file is absent."

## Example: builder report

```markdown
## Report: add GetByEmail method

### Status
complete

### Files touched
| Path | Action | Summary |
|------|--------|---------|
| `pkg/service/user.go` | modified | added `GetByEmail(ctx, email)`; wraps repository errors with context |
| `pkg/service/user_test.go` | modified | added 4 table-driven cases: found, not-found, db-error, canceled-ctx |

### Evidence
$ go build ./...
$ go test ./pkg/service/... -race
ok  	example/pkg/service	0.203s

### Follow-ups
- `UserRepository.FindByEmail` ignores context cancellation — file a separate task.
```

## Why structured, not prose

- **Lead parses it.** In multi-wave orchestration, `lead` reads each report and decides whether to proceed to the next wave. Free-form prose is ambiguous.
- **The report doubles as a PR description.** `Status`/`Files touched`/`Evidence` is already the body of a good commit message.
- **Follow-ups persist.** A structured follow-up field prevents drift. `lead` can fold them into the next wave's spec instead of losing them in chat scrollback.
- **Blockers fail loud.** When status is `blocked`, the section is mandatory — agents can't quietly stall.

## Rationalizations to avoid

| Shortcut | Reality |
|----------|---------|
| "I'll just describe what I did in a paragraph." | Lead can't parse paragraphs into wave decisions. Use the schema. |
| "Evidence is obvious from the diff." | Evidence is the command output that *proves* the diff is correct. Paste it. |
| "No follow-ups needed." | Maybe. But did you really look? If nothing, write `_None._` — don't omit the section. |
| "I'll report success and mention the blocker in passing." | Split: either `complete` with follow-ups, or `blocked` with Blockers. Not both. |
