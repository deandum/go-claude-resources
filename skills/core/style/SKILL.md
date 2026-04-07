---
name: style
description: >
  Code quality principles. Use when setting conventions, configuring
  linters, or doing style-focused reviews. Pair with language-specific
  style skill for naming and formatting rules.
---

# Code Style

Clear is better than clever. Every line should be immediately understandable.

## When to Use

- Setting up conventions for a new project
- Configuring linters and formatters
- Style-focused code reviews
- Resolving naming or formatting disagreements

## When NOT to Use

- Implementation work (use `<lang>/style` skill for language-specific conventions)
- Architecture decisions (use project-structure skill)

## Core Principles

- **Simplicity is the goal**, not the starting point. Don't add abstractions until code demands them.
- **Explicit over implicit**. Boring over brilliant.
- **Consistency** within a codebase trumps personal preference.
- **Automate enforcement** — formatters and linters, not code review comments.

## Naming

- Names describe purpose, not type: `users` not `userSlice`
- Short names for narrow scopes, descriptive for wide scopes
- Package/module names describe what they *provide*, not *contain*
- Avoid generic names: `util`, `common`, `helpers`, `misc`
- Boolean variables/functions: `Is`, `Has`, `Can` prefixes

### Naming Decision Tree

1. Is the scope narrow (loop var, lambda param)? → short name (`i`, `r`, `w`)
2. Is it a well-known abbreviation in the domain? → use it (`ctx`, `db`, `cfg`)
3. Otherwise → descriptive name (`userRepository`, `orderService`)

## Function Design

- Each function does exactly one thing
- Keep functions short (~100 lines max). Longer → consider splitting.
- Early returns for error/edge cases — happy path at minimal indentation
- Limit parameters (>4 suggests config struct or builder)
- Named results only when they improve readability

## Formatting

- Use the language's standard formatter — non-negotiable
- Consistent import grouping: stdlib, external, internal
- No manual alignment of fields or comments

## Comments

- Comments explain *why*, not *what* (code shows what)
- All public/exported names should have doc comments
- Delete commented-out code — version control remembers
- Package-level comments for multi-file packages

## Code Complexity

- Avoid nesting >3 levels (extract functions or use early returns)
- Prefer flat over nested conditionals
- Three similar lines of code beats a premature abstraction
- Cyclomatic complexity >10 → split the function

## Anti-Patterns

- God objects/structs with too many fields or methods
- Interfaces with too many methods (1-5 ideal)
- Deep nesting (>3 levels)
- Naked boolean parameters — use named types or option structs
- `any`/`object`/`interface{}` when concrete type works
- Premature abstraction — "we might need this later"

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "My style is fine" | Consistency beats preference. Use the standard formatter. |
| "Comments are obvious" | Exported names need doc comments. WHY is rarely obvious. |
| "Short names are cryptic" | Short for narrow scopes, descriptive for wide. Both correct in context. |
| "We might need this abstraction" | Three concrete uses before abstracting. YAGNI until proven otherwise. |

## Red Flags

- No formatter configured (inconsistent formatting)
- No linter configured (manual style enforcement doesn't scale)
- Commented-out code blocks (use version control)
- Functions >100 lines
- Nesting >3 levels deep
- "util" or "helpers" package names

## Verification

- [ ] Language formatter applied to all files
- [ ] Linter configured and passing
- [ ] Naming conventions followed consistently
- [ ] Doc comments on all public/exported names
- [ ] No functions >100 lines
- [ ] No nesting >3 levels deep
