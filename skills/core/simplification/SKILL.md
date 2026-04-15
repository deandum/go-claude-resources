---
name: simplification
description: >
  Chesterton's Fence, dead-code removal, YAGNI discipline. Use when
  proposing to delete code, extract a function/class/interface, or
  introduce a new abstraction. Trigger on phrases like "do we need
  this?", "can we remove?", "should we extract?", "let me refactor
  this", "clean this up", or "simplify this" — and proactively
  whenever reviewing a PR that adds indirection, wrapper layers, or
  single-caller helpers. Pair with core/code-review and core/style.
---

# Simplification

The best code is code you don't write. The second best is code you deleted. Simpler code has fewer bugs, is faster to read, and is cheaper to change.

## When to Use

- Refactoring working code
- Reviewing a PR that adds abstraction or indirection
- Deciding whether to extract a function, class, or interface
- Removing a feature, deprecated API, or legacy path
- Before introducing a new dependency, framework, or tool

## When NOT to Use

- While actively fixing a bug — don't conflate cleanup with the fix
- When the team has not agreed on the direction — simplification is a mandate, not a preference
- When tests do not exist — delete code only when you can prove it is unused

## Core Process

### 1. Chesterton's Fence — understand before removing

Before removing any code, branch, or abstraction, answer three questions:

1. **What was this for?** If you don't know, you are not qualified to remove it yet. Find the commit, the issue, the person.
2. **Is that reason still valid?** Codebases outlive their contexts. A workaround for a 2019 bug in a library version you no longer use is dead weight.
3. **What breaks if it is gone?** Prove it with the test suite or a staging environment — not a mental model.

If you can't answer all three, the fence stays.

### 2. Prefer deletion over premature abstraction

YAGNI — You Aren't Gonna Need It. The rule:

- **Duplication in three or more places AND coupled** (a change to one requires a change to all) → consider abstracting
- **Duplication in two places** → almost always leave it
- **"Similar-looking" code that is not coupled** → leave it; it will diverge, and the abstraction you build today will be wrong tomorrow

Abstractions are inventory. Each one has a carrying cost: someone must read it, understand it, and route around it when it does not fit their case. The third coupled duplication tells you the real shape of the abstraction — wait for it.

### 3. Remove, don't comment out

Commented-out code is worse than deleted code:

- Version control remembers everything; comments lie
- Commented blocks rot — imports drift, names change, context vanishes
- They signal uncertainty without resolving it

If you hesitate to delete, you probably shouldn't be deleting yet. Confirm Chesterton's Fence first, then commit the delete.

### 4. Measure with the reader, not the writer

A simpler codebase is one a new reader can navigate. The writer sees simplicity through their own context; that doesn't count. Ask: would someone new to this file, with no git history, understand what it does and why?

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "We might need it later." | You won't. And if you do, `git log` remembers. Delete it. |
| "It's harmless to leave it." | It isn't. It costs attention every time someone reads the file. |
| "Let me abstract this early so we don't duplicate later." | Premature abstraction locks in the wrong shape. Wait for three coupled duplications. |
| "I'll comment it out in case we need to restore it." | That's what version control is for. Delete it. |
| "It took me hours to write — I don't want to throw it away." | Sunk cost. If it's not used, it's not code. |

## Red Flags

- Code commented out with a TODO or FIXME
- Abstractions with a single caller
- Interfaces with one implementation (except test doubles)
- Feature flags for features that shipped years ago
- Config options nobody has touched in over a year
- Helper functions used once, far from their call site
- "Legacy" paths with no active callers
- Deep wrapper chains (`FooService → FooServiceImpl → FooServiceBase → …`)

## Verification

- [ ] Chesterton's Fence applied — I know what it was for, whether that reason holds, and what breaks if removed
- [ ] Tests still pass after the removal (and covered the removed code before)
- [ ] No commented-out code added or left behind
- [ ] No abstraction introduced for fewer than three coupled duplications
- [ ] Reader test passed — a new reader can understand the post-change shape without git history
