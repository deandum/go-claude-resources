---
name: code-review
description: >
  Code review process and quality framework. Use when reviewing PRs,
  auditing code quality, or evaluating AI-generated code. Pair with
  language-specific code-review skill.
---

# Code Review

Systematic review across five axes. Work through each in order. Report findings per category.

## When to Use

- Before merging any PR or change
- After completing a feature implementation
- When evaluating AI-generated code (needs MORE scrutiny, not less)
- After any bug fix (review both the fix and the regression test)
- When refactoring existing code

## When NOT to Use

- Writing code (use builder agent)
- Running tests (use tester agent)
- Designing architecture (use architect agent)

## Core Process

1. **Get the diff** — understand what changed and why
2. **Read surrounding context** — don't review lines in isolation; understand the function, package, callers
3. **Walk each axis** — Correctness → Readability → Architecture → Security → Performance (in order)
4. **Label severity** — every finding gets a severity prefix
5. **Be specific** — quote exact line, explain problem, show the fix
6. **Acknowledge strengths** — note well-written code briefly. Not praise — recognition.
7. **Summarize** — verdict + overview + what was verified

## The Five-Axis Review

### 1. Correctness
- Error handling: every error checked? Proper wrapping?
- Concurrency: races, concurrent task leaks, deadlocks?
- Resource management: files/connections closed? Defer for cleanup?
- Nil/null safety: pointer dereference after error check?
- Edge cases: empty input, zero values, max values?

### 2. Readability & Simplicity
- Naming: clear, consistent, idiomatic?
- Structure: functions <100 lines? Early returns? Minimal nesting?
- Comments: explain WHY not WHAT? No commented-out code?
- Abstractions: earning their complexity? Three lines beats a premature abstraction.

### 3. Architecture
- Package boundaries: dependency direction correct?
- API surface: minimal, consistent, hard to misuse?
- Coupling: can this change without rippling through the system?
- Patterns: consistent with existing codebase?

### 4. Security
- Input validation at boundaries?
- SQL parameterized (never string concat)?
- No secrets in code, logs, or error messages?
- Auth/authz checks present where needed?

### 5. Performance
- N+1 query patterns?
- Unbounded operations (lists without limits, concurrent tasks without bounds)?
- Timeouts on external calls?
- Unnecessary allocations in hot paths?

## Severity Labeling

Every comment MUST have a severity prefix:

| Prefix | Meaning | Author Action |
|--------|---------|---------------|
| **Critical:** | Blocks merge. Security, data loss, crash. | Must fix |
| **Important:** | Bug risk, missing error handling, design issue | Should fix |
| **Suggestion:** | Style, minor optimization, readability | Nice to have |
| **Nit:** | Trivial, optional | May ignore |
| **FYI** | Informational only | No action needed |

## Change Sizing

| Lines Changed | Assessment |
|--------------|------------|
| ~100 | Good — easy to review thoroughly |
| ~300 | Acceptable if single logical change |
| ~1000+ | Too large — must split before review |

### Splitting Strategies

| Strategy | When |
|----------|------|
| **Stack** | Sequential dependencies — submit small change, next one builds on it |
| **By file group** | Different reviewers needed for different parts |
| **Horizontal** | Shared code/stubs first, then consumers |
| **Vertical** | Smaller full-stack slices of the feature |

## Output Format

```
## Review: [package or file]

**Verdict**: [APPROVE / REQUEST CHANGES / COMMENT]

### Critical
- [file:line] Description. Fix: [specific fix]

### Important
- [file:line] Description. Fix: [specific fix]

### Suggestions
- [file:line] Description

### Positive
- [Brief note on what was done well]

### Summary
[1-2 sentences: overall assessment + what was verified]
```

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "LGTM, looks fine" | Rubber-stamping is not reviewing. Check each axis systematically. |
| "It works, so it's correct" | Working code can still have races, leaks, and security holes. |
| "AI-generated code is probably fine" | AI code needs more scrutiny. It's confident and plausible, even when wrong. |
| "It's too big to review properly" | Then it's too big to merge. Split it first. |

## Red Flags

- PRs merged without any review
- Review that only checks "tests pass" (ignoring other axes)
- "LGTM" without evidence of actual review
- Security-sensitive changes without security-focused review
- Large PRs accepted because "splitting is too hard"
- No regression tests with bug fix PRs
- Review comments without severity labels

## Verification

- [ ] All five axes checked in order
- [ ] Every finding has a severity label
- [ ] Critical/Important findings include specific fix recommendations
- [ ] Change size is reasonable (<300 lines, or justified)
- [ ] Tests pass and build succeeds
- [ ] Strengths acknowledged (not just problems)
